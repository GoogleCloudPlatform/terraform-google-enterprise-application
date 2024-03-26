# Changelog

All notable changes to this project will be documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).
This changelog is generated automatically based on [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

## 0.1.0 (2024-03-26)


### ⚠ BREAKING CHANGES

* Bootstrap test integration and change in buckets creation ([#41](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/41))

### Features

* add appfactory integration tests ([#59](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/59)) ([01dd44a](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/01dd44abae4b4d5e12ce5d440fcc3e04b0a1aaae))
* add cloud armor policy ([#48](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/48)) ([b2cc1af](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/b2cc1af3ad3dd20db4700e8138bf9783cdda7f64))
* add cluster and fleet projects ([#25](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/25)) ([841e864](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/841e864dee434eb50f49e099c7808073b497da58))
* add GKE clusters and hub memberships ([#12](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/12)) ([7618b55](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/7618b55e3f7069c9d02baebecaa19afeab3c497c))
* Add multitenant integration test ([#46](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/46)) ([b8b1c10](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/b8b1c10915e2d69cb4d6e62668e9ee4df30998e0))
* add node pool using surge strategy ([#19](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/19)) ([25a50fc](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/25a50fce2177d2ca3bda2def89a7460607ae38d7))
* add phases 2-5 ([#9](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/9)) ([b71a3a9](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/b71a3a951eac9b0321134f085762ff1e83d9050a))
* add prerequisite VPCs and projects ([#11](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/11)) ([626867c](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/626867c51f88f4a066fa0250b85c426f98563635))
* added acm: config sync and policy controller ([#31](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/31)) ([70200c1](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/70200c191b03d08aea362bfbbc4dcd6d8d78bcad))
* added fleet scope and namespace ([#15](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/15)) ([f02c26f](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/f02c26f1f5db55439747fc15e2109f62243040ca))
* added multiclusteringress hub feature for use by multiclustergateway ([#24](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/24)) ([ae268bd](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/ae268bdbe17b7d59d80ee7954d5dc8a12b72d3e3))
* added service mesh ([#27](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/27)) ([207e2bd](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/207e2bd0891de5297c0fe33229864508bf98409e))
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
* switch to release gke module ([#37](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/37)) ([adbb4e6](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/adbb4e6925f42344941219575acafb51e298e4c7))


### Bug Fixes

* add stage 2 outputs ([#17](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/17)) ([f22d434](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/f22d434b05c74872a3fc9c1f4530c51bf8c94b2c))
* **deps:** Update module github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test to v0.12.0 ([#14](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/14)) ([92d805b](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/92d805b23c35b19c60989d12ec7b9bc0084392d2))
* **deps:** Update module github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test to v0.12.1 ([#16](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/16)) ([6ceaaf0](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/6ceaaf0f360a3a50f79adc5181739384fbe1d57d))
* **deps:** Update Terraform terraform-google-modules/kubernetes-engine/google to v30 ([#18](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/18)) ([56c3360](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/56c3360788af251d30a75c2e7cacf4c8d3b075db))
* only create a single cluster in dev ([#23](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/23)) ([846f68e](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/846f68e928bd6ff640a807bc7de4269d624a2588))
* provider_meta and test boilerplate ([#6](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/issues/6)) ([646dc9f](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/commit/646dc9fe3029087cbd0ba65a527717b5bc0dedbd))

## [0.1.0](https://github.com/terraform-google-modules/terraform-google-enterprise-application/releases/tag/v0.1.0) - 20XX-YY-ZZ

### Features

- Initial release

[0.1.0]: https://github.com/terraform-google-modules/terraform-google-enterprise-application/releases/tag/v0.1.0
