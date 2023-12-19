# Changelog

## [0.1.13](https://github.com/rancher/terraform-aws-rke2/compare/v0.1.12...v0.1.13) (2023-12-19)


### Bug Fixes

* updatecli should use a public key for a loaded private key ([#108](https://github.com/rancher/terraform-aws-rke2/issues/108)) ([eca825e](https://github.com/rancher/terraform-aws-rke2/commit/eca825e293497fb59e73edaed6e6a75aa245bda9))

## [0.1.12](https://github.com/rancher/terraform-aws-rke2/compare/v0.1.11...v0.1.12) (2023-12-15)


### Bug Fixes

* add a small line to validate leftover findings ([#79](https://github.com/rancher/terraform-aws-rke2/issues/79)) ([36fca7a](https://github.com/rancher/terraform-aws-rke2/commit/36fca7af899d1f85675159e97ecfa4145d2a92e9))
* add aws auth to cleanup ([#85](https://github.com/rancher/terraform-aws-rke2/issues/85)) ([bb01545](https://github.com/rancher/terraform-aws-rke2/commit/bb01545a49c134d320e193fb943cc202dd8dd374))
* add body func ([#94](https://github.com/rancher/terraform-aws-rke2/issues/94)) ([62b5b2a](https://github.com/rancher/terraform-aws-rke2/commit/62b5b2acd835dd605f240faf2b9a87f21b13afcb))
* add filter for workflows in progress ([#102](https://github.com/rancher/terraform-aws-rke2/issues/102)) ([e96b616](https://github.com/rancher/terraform-aws-rke2/commit/e96b6166eb95b2409c8d315b92b1f31a952113fc))
* add id to names in examples and add quotes to json for issue ([#95](https://github.com/rancher/terraform-aws-rke2/issues/95)) ([f36ffe4](https://github.com/rancher/terraform-aws-rke2/commit/f36ffe49cb5a07405294664dfb4cad6730c264b0))
* add missing pipe ([#83](https://github.com/rancher/terraform-aws-rke2/issues/83)) ([8af3667](https://github.com/rancher/terraform-aws-rke2/commit/8af36670799ed39fc70b40e53be8a77b6fd1c9f2))
* add output to issue ([#90](https://github.com/rancher/terraform-aws-rke2/issues/90)) ([358e5e4](https://github.com/rancher/terraform-aws-rke2/commit/358e5e4370020350585f03ac8d394cd90e5643ca))
* add output to workflow ([#91](https://github.com/rancher/terraform-aws-rke2/issues/91)) ([0d126c4](https://github.com/rancher/terraform-aws-rke2/commit/0d126c463fb5775bae4bf9f2f5f88aaed00d1eb0))
* break down leftovers script into functions and add output ([#93](https://github.com/rancher/terraform-aws-rke2/issues/93)) ([57fb1cb](https://github.com/rancher/terraform-aws-rke2/commit/57fb1cbf56b195c5d446543e5dae2506e419764d))
* echo instead of return values in bash funcs ([#96](https://github.com/rancher/terraform-aws-rke2/issues/96)) ([57215ee](https://github.com/rancher/terraform-aws-rke2/commit/57215ee17bf6e9722cc7fe4582f1638662e0362c))
* filter ids and improve workflow names ([#81](https://github.com/rancher/terraform-aws-rke2/issues/81)) ([a59cb1c](https://github.com/rancher/terraform-aws-rke2/commit/a59cb1cd5e1f1a4bced3f86662a13956ce4d038f))
* jq needs a query ([#100](https://github.com/rancher/terraform-aws-rke2/issues/100)) ([55bd936](https://github.com/rancher/terraform-aws-rke2/commit/55bd93679b853a2f78ce28f6292ced7041261594))
* put all jq in one line ([#82](https://github.com/rancher/terraform-aws-rke2/issues/82)) ([97872a6](https://github.com/rancher/terraform-aws-rke2/commit/97872a61770edabe09d05477b231e8f633bbb7bc))
* remove lines from echos and all line feeds in json ([#99](https://github.com/rancher/terraform-aws-rke2/issues/99)) ([2ef6c3b](https://github.com/rancher/terraform-aws-rke2/commit/2ef6c3bd2f10716a70ce8259a6e752d291e51941))
* single quote ids ([#84](https://github.com/rancher/terraform-aws-rke2/issues/84)) ([3bb6ac6](https://github.com/rancher/terraform-aws-rke2/commit/3bb6ac69042dab2308dbcbc9c2fea352efb2e204))
* try using a file to process auth issues from leftovers ([#86](https://github.com/rancher/terraform-aws-rke2/issues/86)) ([bad1f5b](https://github.com/rancher/terraform-aws-rke2/commit/bad1f5bca7ebd4fd9d39a7757d09252c19659a1d))
* use file ([#98](https://github.com/rancher/terraform-aws-rke2/issues/98)) ([1a41f88](https://github.com/rancher/terraform-aws-rke2/commit/1a41f884343cddd7fbc267c0998daef01e3787ab))
* use file to hold data ([#97](https://github.com/rancher/terraform-aws-rke2/issues/97)) ([a785f03](https://github.com/rancher/terraform-aws-rke2/commit/a785f037c67723c156fdbc39b205d43c5ed31e8a))

## [0.1.11](https://github.com/rancher/terraform-aws-rke2/compare/v0.1.10...v0.1.11) (2023-12-14)


### Bug Fixes

* introduce leftovers and configure updatecli to sign commits ([#77](https://github.com/rancher/terraform-aws-rke2/issues/77)) ([f0d3004](https://github.com/rancher/terraform-aws-rke2/commit/f0d300437231090d0da5cf403c2d73561467131d))

## [0.1.10](https://github.com/rancher/terraform-aws-rke2/compare/v0.1.9...v0.1.10) (2023-12-12)


### Bug Fixes

* add live-example-rpm ([#73](https://github.com/rancher/terraform-aws-rke2/issues/73)) ([b67d240](https://github.com/rancher/terraform-aws-rke2/commit/b67d240e6d7823a21330001334ea7918b21ae524))
* bump actions/setup-go from 4 to 5 ([#71](https://github.com/rancher/terraform-aws-rke2/issues/71)) ([130b7fb](https://github.com/rancher/terraform-aws-rke2/commit/130b7fbf41a5787f61933ee367c47e2aa96368d1))
* update access mod ([#74](https://github.com/rancher/terraform-aws-rke2/issues/74)) ([97b6615](https://github.com/rancher/terraform-aws-rke2/commit/97b66159f69103db04776267433483f131ec940b))
* use proper default branch for Go ([#75](https://github.com/rancher/terraform-aws-rke2/issues/75)) ([47a46a5](https://github.com/rancher/terraform-aws-rke2/commit/47a46a5f569af350291e37aaecfa4faac01f7772))

## [0.1.9](https://github.com/rancher/terraform-aws-rke2/compare/v0.1.8...v0.1.9) (2023-12-08)


### Bug Fixes

* use local values rather than derived ones when possible ([#69](https://github.com/rancher/terraform-aws-rke2/issues/69)) ([c9099e4](https://github.com/rancher/terraform-aws-rke2/commit/c9099e42f7c06c1f4242a114a1040b2a68953284))

## [0.1.8](https://github.com/rancher/terraform-aws-rke2/compare/v0.1.7...v0.1.8) (2023-12-07)


### Bug Fixes

* add a console password for troubleshooting using ec2 console ([#62](https://github.com/rancher/terraform-aws-rke2/issues/62)) ([ba81aaf](https://github.com/rancher/terraform-aws-rke2/commit/ba81aafcf4760654de58781b1a78441911173f29))
* bump google-github-actions/release-please-action from 3 to 4 ([#53](https://github.com/rancher/terraform-aws-rke2/issues/53)) ([edb0af4](https://github.com/rancher/terraform-aws-rke2/commit/edb0af44a821b924714aea37c88d506af553b4ab))
* fix prefix and remove unused name ([#68](https://github.com/rancher/terraform-aws-rke2/issues/68)) ([c5578e7](https://github.com/rancher/terraform-aws-rke2/commit/c5578e7b73dfa7537b3e2c6fd404102e8d478a14))
* increase timeout to 15 min ([#56](https://github.com/rancher/terraform-aws-rke2/issues/56)) ([2ba0a5f](https://github.com/rancher/terraform-aws-rke2/commit/2ba0a5fdc5062295b3bf3dba87e978a86936236d))
* install nix after restoring cache ([#64](https://github.com/rancher/terraform-aws-rke2/issues/64)) ([ef23060](https://github.com/rancher/terraform-aws-rke2/commit/ef23060995ad2cdeed168ace3eb1aa7005798973))
* remove nix cache operations ([#57](https://github.com/rancher/terraform-aws-rke2/issues/57)) ([a8ab72f](https://github.com/rancher/terraform-aws-rke2/commit/a8ab72ffc21b208479285eee2a056ab2371081ad))
* remove the id from the name in examples ([#67](https://github.com/rancher/terraform-aws-rke2/issues/67)) ([00b0097](https://github.com/rancher/terraform-aws-rke2/commit/00b0097847619f608fed7aaa070861a46c1e32d2))
* remove the release title specification ([#59](https://github.com/rancher/terraform-aws-rke2/issues/59)) ([b5052f5](https://github.com/rancher/terraform-aws-rke2/commit/b5052f532e119e0f50fd69eade0331cd577fd706))
* set permissions on /nix/store after setting owner ([#60](https://github.com/rancher/terraform-aws-rke2/issues/60)) ([0f38efa](https://github.com/rancher/terraform-aws-rke2/commit/0f38efa08cd769d2f03a27d8e609c151404892b6))
* temp set the ec2 console password using passwd in example ([#63](https://github.com/rancher/terraform-aws-rke2/issues/63)) ([eb0400b](https://github.com/rancher/terraform-aws-rke2/commit/eb0400b0e2adc41794b084414edc5017179d82cd))
* troubleshoot configs ([#58](https://github.com/rancher/terraform-aws-rke2/issues/58)) ([ffea124](https://github.com/rancher/terraform-aws-rke2/commit/ffea1249c3383403b93824cbe3d8d44240a5cfb4))
* try to make ci and local environment match more closely ([#65](https://github.com/rancher/terraform-aws-rke2/issues/65)) ([7b3a5c4](https://github.com/rancher/terraform-aws-rke2/commit/7b3a5c44753e3667861587627afc921fe4141585))
* update install mod to 0.3.3 ([#66](https://github.com/rancher/terraform-aws-rke2/issues/66)) ([f74df00](https://github.com/rancher/terraform-aws-rke2/commit/f74df00c9d63e61a902ed4fa5052efe715ed871d))
* update mods and surface new options ([#55](https://github.com/rancher/terraform-aws-rke2/issues/55)) ([3a8413f](https://github.com/rancher/terraform-aws-rke2/commit/3a8413fa04789d52d88437c5067f3becdec56d2c))
* upgrade install mod to v0.3 ([#50](https://github.com/rancher/terraform-aws-rke2/issues/50)) ([5e4d599](https://github.com/rancher/terraform-aws-rke2/commit/5e4d5999777b7a61b7eb17131fa1157766ae3add))
* use sudo to ensure nix store path ([#61](https://github.com/rancher/terraform-aws-rke2/issues/61)) ([aefb483](https://github.com/rancher/terraform-aws-rke2/commit/aefb483bd9424d7b0a29c1d9592268524f7d47f1))
* use the file function to get the extra config content ([#52](https://github.com/rancher/terraform-aws-rke2/issues/52)) ([d461a3b](https://github.com/rancher/terraform-aws-rke2/commit/d461a3b2b81da5c548c03cfe90b7b905c1cac36c))

## [0.1.7](https://github.com/rancher/terraform-aws-rke2/compare/v0.1.6...v0.1.7) (2023-11-30)


### Bug Fixes

* Upgrade access 1.1 ([#48](https://github.com/rancher/terraform-aws-rke2/issues/48)) ([50abf20](https://github.com/rancher/terraform-aws-rke2/commit/50abf20d43a55c93c1d4afee6168cf1447f3d44c))

## [0.1.6](https://github.com/rancher/terraform-aws-rke2/compare/v0.1.5...v0.1.6) (2023-11-28)


### Bug Fixes

* upgrade config mod ([#46](https://github.com/rancher/terraform-aws-rke2/issues/46)) ([868b8a1](https://github.com/rancher/terraform-aws-rke2/commit/868b8a1f5b5107ab97ae22498578cb78c1f6f395))

## [0.1.5](https://github.com/rancher/terraform-aws-rke2/compare/v0.1.4...v0.1.5) (2023-11-28)


### Bug Fixes

* update install mod and configure generated files ([#43](https://github.com/rancher/terraform-aws-rke2/issues/43)) ([acc03b9](https://github.com/rancher/terraform-aws-rke2/commit/acc03b954aaf4605e6df7c64aac5f33ec71000c6))
* upgrade the github provider, skip .42 ([#45](https://github.com/rancher/terraform-aws-rke2/issues/45)) ([7119ea8](https://github.com/rancher/terraform-aws-rke2/commit/7119ea871f29cf983a46ced7008b6c90185d73eb))

## [0.1.4](https://github.com/rancher/terraform-aws-rke2/compare/v0.1.3...v0.1.4) (2023-11-10)


### Bug Fixes

* add 'Job' tag to all resources ([#42](https://github.com/rancher/terraform-aws-rke2/issues/42)) ([e99caef](https://github.com/rancher/terraform-aws-rke2/commit/e99caef1ec0d505db91e152194677eb6d8eef658))
* add write-all to updatecli workflow ([#41](https://github.com/rancher/terraform-aws-rke2/issues/41)) ([07106b5](https://github.com/rancher/terraform-aws-rke2/commit/07106b59db2baf84890f670438308ee98080c384))
* updatecli repoid typo fixed ([#39](https://github.com/rancher/terraform-aws-rke2/issues/39)) ([e9d2a9a](https://github.com/rancher/terraform-aws-rke2/commit/e9d2a9aa509217d0c2c9f1142f3f6f180259a4e5))

## [0.1.3](https://github.com/rancher/terraform-aws-rke2/compare/v0.1.2...v0.1.3) (2023-11-10)


### Bug Fixes

* add explicit token to terratest ([#34](https://github.com/rancher/terraform-aws-rke2/issues/34)) ([b775819](https://github.com/rancher/terraform-aws-rke2/commit/b775819e6d10b2ad7e84324d8ff1777b8c7a75d5))
* add github org to environment variables ([#37](https://github.com/rancher/terraform-aws-rke2/issues/37)) ([3b6c4b4](https://github.com/rancher/terraform-aws-rke2/commit/3b6c4b4a28a6a4f852737f1a2889c5c6267168c5))
* add terraform and leftovers to nix ([#32](https://github.com/rancher/terraform-aws-rke2/issues/32)) ([cd8998a](https://github.com/rancher/terraform-aws-rke2/commit/cd8998a9b115540c1d0958a3c2660da8fa9aacb1))
* add token to actions ([#36](https://github.com/rancher/terraform-aws-rke2/issues/36)) ([35cb61c](https://github.com/rancher/terraform-aws-rke2/commit/35cb61c5ca43282f115661d92d81e713dd120fc9))
* add user write to workflow token ([#35](https://github.com/rancher/terraform-aws-rke2/issues/35)) ([5aa3c79](https://github.com/rancher/terraform-aws-rke2/commit/5aa3c793fc447615be73306b9971b6bb403137f3))
* try adding all permissions ([#38](https://github.com/rancher/terraform-aws-rke2/issues/38)) ([46a3150](https://github.com/rancher/terraform-aws-rke2/commit/46a315016696c5d32e855bd33c3d3f0f911e22e5))

## [0.1.2](https://github.com/rancher/terraform-aws-rke2/compare/v0.1.1...v0.1.2) (2023-10-31)


### Bug Fixes

* env typo ([#30](https://github.com/rancher/terraform-aws-rke2/issues/30)) ([eed6646](https://github.com/rancher/terraform-aws-rke2/commit/eed66465a325e7861767b077e0ad2c7e6daf6a71))

## [0.1.1](https://github.com/rancher/terraform-aws-rke2/compare/v0.1.0...v0.1.1) (2023-10-31)


### Bug Fixes

* point updatecli to main ([#28](https://github.com/rancher/terraform-aws-rke2/issues/28)) ([0de3804](https://github.com/rancher/terraform-aws-rke2/commit/0de38044d1d9fb5072501c762d2afc4561f71cca))

## [0.1.0](https://github.com/rancher/terraform-aws-rke2/compare/v0.0.4...v0.1.0) (2023-10-31)


### Features

* upgrate modules, fix tests, pin flake, add autoupdate ([6362595](https://github.com/rancher/terraform-aws-rke2/commit/63625950de28f2afc2b655b5fc215938a1b87c90))


### Bug Fixes

* add rpm test and new workflows ([faebe90](https://github.com/rancher/terraform-aws-rke2/commit/faebe907a8fa6600265708531621d85dd764537e))
* add warnings and suggestions to .envrc for first time contributors ([8284ff1](https://github.com/rancher/terraform-aws-rke2/commit/8284ff154bfd112f010674635b29319b2a8ef24e))
* create a vpc and subnet to make rpm install easier for new users and use us-east-1 ([9d04b02](https://github.com/rancher/terraform-aws-rke2/commit/9d04b02a8b0d90ace1c129e34e7a435320e437e4))
* range from server count to total count ([7151f14](https://github.com/rancher/terraform-aws-rke2/commit/7151f1473fa962500ae8f4834212f1a5859523da))
* typo in variable ([ccdaa96](https://github.com/rancher/terraform-aws-rke2/commit/ccdaa96d8906ccfcc81ad2f45a6cf0ba4ede05bb))
* upgrade internal modules ([7dae5e7](https://github.com/rancher/terraform-aws-rke2/commit/7dae5e7681ecc704772451ee94e65fc5c86c832e))
