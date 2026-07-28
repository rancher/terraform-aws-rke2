# Bug Report: `panic: runtime error: invalid memory address or nil pointer dereference` in `ValidateResourceConfig` on Computed Attributes

## 1. Summary
When using `rancher/file` version `v2.4.x` (specifically `v2.4.1`), the provider crashes with a `SIGSEGV` nil pointer dereference during `ValidateResourceConfig` execution. This panic is triggered when a `file_local` (or similar) resource has a configuration attribute (like `contents` or `permissions`) that is a **computed value** depending on another resource in the same dependency graph (e.g., `contents = base64decode(file_local_snapshot.some_resource.snapshot)`). 

When the dependency is resolved during the apply phase, Terraform executes a late validation call (`ValidateResourceConfig`) with the resolved config. The provider's validation logic fails to check if these computed properties are null or unknown in the request config, resulting in a nil pointer dereference.

---

## 2. Environmental Context
*   **Provider Version:** `rancher/file v2.4.1` (Regression introduced in `v2.4.0` / `v2.4.1`)
*   **Terraform Version:** `v1.5.7` (and reproducible on `v1.6+`)
*   **Operating System:** SUSE Linux Enterprise Server (SLES) 16.0 / Linux Kernel 6.12
*   **Go Runtime Version:** Go 1.26 (or Go 1.24+ depending on compilation)

---

## 3. Crash Stack Trace
```text
panic: runtime error: invalid memory address or nil pointer dereference
[signal SIGSEGV: segmentation violation code=0x1 addr=0x20 pc=0xa68cb4]

goroutine 309 gp=0x1751fc384960 m=8 mp=0x1751fc27b008 [running]:
panic({0xc7d6a0?, 0x1524820?})
  runtime/panic.go:879 +0x16f fp=0x1751fc0cb758 sp=0x1751fc0cb6a8 pc=0x487c2f
runtime.panicmem(...)
  runtime/panic.go:336
runtime.sigpanic()
  runtime/signal_unix.go:931 +0x378 fp=0x1751fc0cb7b8 sp=0x1751fc0cb758 pc=0x48a218
google.golang.org/grpc.(*Server).processUnaryRPC.func3({0xd34140, 0x1751fdec62d0})
  google.golang.org/grpc@v1.81.1/server.go:1403 +0xd4 fp=0x1751fc0cb8c0 sp=0x1751fc0cb7b8 pc=0xa68cb4
github.com/hashicorp/terraform-plugin-go/tfprotov6/internal/tfplugin6._Provider_ValidateResourceConfig_Handler({0xd9f280, 0x1751fc24e780}, {0xe1ca58, 0x1751fdebfd10}, 0x1751fdbd3900, 0x0)
  github.com/hashicorp/terraform-plugin-go@v0.31.0/tfprotov6/internal/tfplugin6/tfplugin6_grpc.pb.go:831 +0x55 fp=0x1751fc0cb910 sp=0x1751fc0cb8c0 pc=0xb02615
google.golang.org/grpc.(*Server).processUnaryRPC(0x1751fc33c248, {0xe1ca58, 0x1751fdebfc80}, 0x1751fde81ba0, 0x1751fc33b650, 0x153ea60, 0x0)
  google.golang.org/grpc@v1.81.1/server.go:1430 +0x11d2 fp=0x1751fc0cbdd0 sp=0x1751fc0cb910 pc=0xa67612
```

---

## 4. Root-Cause Analysis
During a multi-resource `terraform apply` sequence, when resource A is successfully created, the computed outputs of A become known. If resource B (managed by the `file` provider) has an attribute depending on resource A's output, Terraform Core must evaluate and perform late validation of resource B's configuration before applying it.

When calling `ValidateResourceConfig` during this apply-phase evaluation:
1.  Terraform passes a `tfprotov6.ValidateResourceConfigRequest` containing the dynamic config.
2.  In the `rancher/file` provider code (specifically under the `file_local` resource implementation), the validation logic attempts to extract and process configuration attributes (such as `contents` or `permissions`).
3.  Because this validation occurs on computed/unknown parameters, the provider's `ValidateConfig` implementation attempts to read or dereference these attributes directly (e.g., casting them to raw Go strings or pointers like `*string` or calling `.ValueString()` / `.ValueStringPointer()`) **without checking if the values are Null or Unknown first**.
4.  Since the configuration value is represented in the SDK/Framework request as a null/unknown (which translates to a nil pointer or unallocated structure inside the request message), this lack of a safety check causes a direct `invalid memory address or nil pointer dereference` panic, crashing the entire plugin process.

---

## 5. Instructions for the Correction (Actionable Steps for an Agent)

To fix this issue, an agent working on the `rancher/file` provider must implement defensive checks in the resource-validation schemas:

### A. Locate the Target Files
Search the codebase for the `ValidateConfig` method or any custom validation functions on the `file_local` (and other related) resource types:
*   Look for implementations of `resource.ResourceWithValidateConfig` or `resource.Resource` that declare `ValidateConfig`:
    ```go
    func (r *FileLocalResource) ValidateConfig(ctx context.Context, req resource.ValidateConfigRequest, resp *resource.ValidateConfigResponse)
    ```

### B. Identify Unsafe Pointer/Attribute Accesses
Within the validation method, inspect how configuration values are being read from the request. Typical unsafe patterns to look for:
1.  **Direct Pointer Dereferencing:**
    ```go
    // ❌ UNSAFE: If contents is null or unknown, contentsStr will be nil and dereferencing it will panic!
    var contents *string
    req.Config.GetAttribute(ctx, path.Root("contents"), &contents)
    if *contents == "" { ... } 
    ```
2.  **Unchecked Framework Types:**
    ```go
    // ❌ UNSAFE: Calling .ValueString() or reading raw values from a null/unknown attribute without checking IsNull() or IsUnknown()
    var contents types.String
    req.Config.GetAttribute(ctx, path.Root("contents"), &contents)
    _ = contents.ValueString() // Can panic or cause unexpected behavior if unvalidated
    ```

### C. Apply the Correction
Implement defensive checks to ensure the validation logic is immediately skipped if the attribute is either **Null** or **Unknown** (which is expected and normal during plan/late-apply phases):

```go
//  SAFE IMPLEMENTATION (using terraform-plugin-framework)
var contents basetypes.StringValue
diags := req.Config.GetAttribute(ctx, path.Root("contents"), &contents)
resp.Diagnostics.Append(diags...)
if resp.Diagnostics.HasError() {
    return
}

// Skip validation entirely if the value is Null or Unknown (computed)
if contents.IsNull() || contents.IsUnknown() {
    return
}

// Perform safe validation only when the value is fully resolved
contentsStr := contents.ValueString()
if len(contentsStr) == 0 {
    // ... custom validation logic ...
}
```

By ensuring that `ValidateConfig` instantly exits early when a computed attribute `IsUnknown()` or `IsNull()`, the late-apply validation will succeed cleanly and the crash will be fully resolved!
