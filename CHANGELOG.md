# Changelog

All notable changes to this project will be documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).
This changelog is generated automatically based on [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

## 0.1.0 (2024-05-10)


### ⚠ BREAKING CHANGES

* Bootstrap test integration and change in buckets creation ([#41](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/41))

### Features

* **2-multitenant:** initial README, tfvar, and variable object ([#84](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/84)) ([6b28838](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/6b28838ac414dd86ad3109affd93adcffd173872))
* add appfactory integration tests ([#59](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/59)) ([01dd44a](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/01dd44abae4b4d5e12ce5d440fcc3e04b0a1aaae))
* add cloud armor policy ([#48](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/48)) ([b2cc1af](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/b2cc1af3ad3dd20db4700e8138bf9783cdda7f64))
* add cluster and fleet projects ([#25](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/25)) ([841e864](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/841e864dee434eb50f49e099c7808073b497da58))
* add GKE clusters and hub memberships ([#12](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/12)) ([7618b55](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/7618b55e3f7069c9d02baebecaa19afeab3c497c))
* add integration tests 2-multitenant ([#91](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/91)) ([2948189](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/2948189a02b6e7e014c94b55c45da18cdfa75019))
* Add multitenant integration test ([#46](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/46)) ([b8b1c10](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/b8b1c10915e2d69cb4d6e62668e9ee4df30998e0))
* add node pool using surge strategy ([#19](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/19)) ([25a50fc](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/25a50fce2177d2ca3bda2def89a7460607ae38d7))
* add phases 2-5 ([#9](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/9)) ([b71a3a9](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/b71a3a951eac9b0321134f085762ff1e83d9050a))
* add prerequisite VPCs and projects ([#11](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/11)) ([626867c](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/626867c51f88f4a066fa0250b85c426f98563635))
* added acm: config sync and policy controller ([#31](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/31)) ([70200c1](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/70200c191b03d08aea362bfbbc4dcd6d8d78bcad))
* added appfactory for other 5 apps ([#79](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/79)) ([1038c4d](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/1038c4d5a3568acba92daaf551e264e49881d237))
* added ci/cd pipeline for the frontend service ([#51](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/51)) ([7c1c50c](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/7c1c50cc6b979abb6b1c9da0be796553e96cf663))
* added cicd for accounts and ledger services for cymbal bank app ([#69](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/69)) ([8bfb465](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/8bfb465c4038bcd47058e0b4f3b0ed0bf41776dc))
* added cloud armor rule to block xss attack ([#58](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/58)) ([d47ff70](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/d47ff709ae62843176b9eb2512d02271d655d7f1))
* added fleet scope and namespace ([#15](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/15)) ([f02c26f](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/f02c26f1f5db55439747fc15e2109f62243040ca))
* added fleet scope logging ([#26](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/26)) ([d2ec68c](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/d2ec68c185702a33ed5612468e984f2ad2cbc035))
* added gateway and asm ingress k8s resources ([#65](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/65)) ([5034fee](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/5034fee639b8f2586bafea9b63f5245d24d6d939))
* added integration tests to the CI for the 5 other apps ([#78](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/78)) ([13615d0](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/13615d09e25b7b66d5dd68e9f3e2e489c8855c1e))
* added k8s manifests for cymbal bank frontend ([#68](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/68)) ([a0dda5c](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/a0dda5cec8c4160ea635f9f0b548d72a84e38aaf))
* added labels, permissions needed for service mesh, and multi cl… ([#54](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/54)) ([0976081](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/097608112a08aae52a8b25e6a095d0acbb17b194))
* added multiclusteringress hub feature for use by multiclustergateway ([#24](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/24)) ([ae268bd](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/ae268bdbe17b7d59d80ee7954d5dc8a12b72d3e3))
* added namespace for accounts and ledger with label istio-injection ([#83](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/83)) ([d93659f](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/d93659fff8fe240e1882bc974fbf43ba20869bef))
* added service mesh ([#27](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/27)) ([207e2bd](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/207e2bd0891de5297c0fe33229864508bf98409e))
* added sql database ([#72](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/72)) ([bc5ebec](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/bc5ebecaa8d55580311915f94d5e9233f90af1be))
* added virtual service and destination rule to allow for localit… ([#56](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/56)) ([84cff84](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/84cff84a1b9c0325e034d7b769590737c7641d50))
* adjusted sqli cloudarmor rule sensitivity level 1 to allow for cymbal bank app ([#85](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/85)) ([fca30d6](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/fca30d6504e9ebc781157a865d2e26609c7a2512))
* Application factory phase ([#38](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/38)) ([2e95d39](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/2e95d39de98ef7a4c3e4ed97616e3891491dabf5))
* Application Source phase folder ([#42](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/42)) ([fc83bcc](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/fc83bcc2b7a50242f625f0417397714b2e0b7a83))
* bootstrap phase ([#8](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/8)) ([06b47d7](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/06b47d7e8c0bb82d7a60a2b74b8888a5f45f575b))
* Bootstrap test integration and change in buckets creation ([#41](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/41)) ([6f5421e](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/6f5421eb4c99a0441ea081189814e7658192acc1))
* **cluster:** enable binauthz ([#36](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/36)) ([e6135dc](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/e6135dc6ace4dbc786801552f403f46e84f26f4b))
* **cluster:** enabled balanced autoscaling ([#34](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/34)) ([cb43517](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/cb435173d8b28a7f53b0918e825699aa1e459830))
* **cluster:** switch to private cluster ([#35](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/35)) ([779db70](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/779db70652cf2a2ab87b2d4efe0b50c9e92778ac))
* create ip_address ([#50](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/50)) ([5c2c7b9](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/5c2c7b944aa4c34670c86f45a4f5d0a7e54c5c2e))
* create multiple namespaces with namespace_ids, one namespace per scope … ([#40](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/40)) ([e59bb7f](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/e59bb7ffe99a670f555a39c59f039678bd7f83f4))
* cross_project_sa upstream ([#39](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/39)) ([7fcc0d9](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/7fcc0d97f9f5dbaa7dc04b13c06546e904672dea))
* enable workload identity ([#49](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/49)) ([5dd8784](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/5dd8784124b0e0977fe00696da94f894c3554296))
* **fleetscope:** add poco pss-baseline and fleet_project_id ([#105](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/105)) ([a0ae960](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/a0ae9609b04f5f273c4432314a72d6cb0f668be5))
* gateway and ingress ([#55](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/55)) ([e118ebb](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/e118ebb72a5ccefd3a1025c4c1b9ff2fcee064dc))
* initial fleetscope README, tfvar, and variable object ([#86](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/86)) ([4b6cec2](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/4b6cec222ef13720399187de78feff4510ca3d52))
* Integration tests fleetscope ([#61](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/61)) ([454618c](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/454618cb58989383332c6e913da5cd1907a2d556))
* moved db from 2-multitenant to 5-appinfra ([#96](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/96)) ([f197505](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/f197505bea6ae6cb91d5c3d6261c4f7ff72bbd4e))
* switch to release gke module ([#37](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/37)) ([adbb4e6](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/adbb4e6925f42344941219575acafb51e298e4c7))
* switched to use Cymbal Bank logo and title ([#76](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/76)) ([a1a0754](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/a1a0754dcfb70472e36839472de79fc584e800a1))


### Bug Fixes

* add stage 2 outputs ([#17](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/17)) ([f22d434](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/f22d434b05c74872a3fc9c1f4530c51bf8c94b2c))
* **appfactory:** add clouddeploy api to app admin project ([#114](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/114)) ([014b8da](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/014b8da9998d62f99de6759e1d09623ea70bfd83))
* **CI:** use larger collusion domain for eab_cluster_project suffix ([#100](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/100)) ([60497b1](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/60497b17bb76d7aee3740f8f92a153c2bcc7fbee))
* consolidate fleet into gke project ([#64](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/64)) ([69b2a91](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/69b2a9108c2d38dfd1a9a9b4bc560e318fe7b37c))
* **deps:** Update module github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test to v0.12.0 ([#14](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/14)) ([92d805b](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/92d805b23c35b19c60989d12ec7b9bc0084392d2))
* **deps:** Update module github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test to v0.12.1 ([#16](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/16)) ([6ceaaf0](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/6ceaaf0f360a3a50f79adc5181739384fbe1d57d))
* **deps:** Update Terraform terraform-google-modules/kubernetes-engine/google to v30 ([#18](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/18)) ([56c3360](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/56c3360788af251d30a75c2e7cacf4c8d3b075db))
* **deps:** Update Terraform terraform-google-modules/project-factory/google to v15 ([#118](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/118)) ([7aafd39](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/7aafd39dcf02b46a75bd7cfd7f9e7bd74bfee7e4))
* **fleetscope:** prevent possible race condition ([#106](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/106)) ([2a7637f](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/2a7637f3af38e21a17ff18ac61efc0d72a722ab7))
* only create a single cluster in dev ([#23](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/23)) ([846f68e](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/846f68e928bd6ff640a807bc7de4269d624a2588))
* provider_meta and test boilerplate ([#6](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/6)) ([646dc9f](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/646dc9fe3029087cbd0ba65a527717b5bc0dedbd))
* use google_project_service_identity for servicemesh sa ([#66](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/66)) ([1964445](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/196444554d1045df2bd3dfa24d597e48543f1672))

## [0.1.0](https://github.com/terraform-google-modules/terraform-google-enterprise-application/releases/tag/v0.1.0) - 20XX-YY-ZZ

### Features

- Initial release

[0.1.0]: https://github.com/terraform-google-modules/terraform-google-enterprise-application/releases/tag/v0.1.0
