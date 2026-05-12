output "output" {
  value = { for k, v in jsondecode(base64decode(file_local_snapshot.persist_outputs.snapshot)) : k => v.value }
}
