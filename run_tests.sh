for f in $(find . -name '*.terraform' -or -name '*.tfstate*' -or -name '*.terraform.lock**'); do rm -rf $f; done
export SERVICE_ACCOUNT_JSON=$(< credentials.json)
init_credentials
export TF_VAR_service_perimeter_mode="ENFORCE"
export TF_VAR_access_level_members="user:amandak@ciandt.com,user:amandak@clsecteam.com,user:amandak@clseclab.com,serviceAccount:sa-tf-seed@prj-seed-447912.iam.gserviceaccount.com,user:dandrade@ciandt.com,user:renatojr@ciandt.com,user:renatojr@clsecteam.com,user:ccolin@clsecteam.com,user:ccolin@ciandt.com"
export TF_VAR_branch_name="test"
export TF_VAR_create_cloud_nat=false
export TF_VAR_single_project=true
export TF_VAR_cloud_build_sa="sa-tf-seed@prj-seed-447912.iam.gserviceaccount.com"
unset single_project_example_type
export single_project_example_type="CONFIDENTIAL_NODES"

source /usr/local/bin/task_helper_functions.sh && prepare_environment && cd ../../ && \
cft test run TestValidateStartupScript --stage verify --verbose && \
gcloud storage cp gs://$(terraform -chdir=/workspace/test/setup output -raw gitlab_secret_project)-ssl-cert/gitlab.crt /usr/local/share/ca-certificates  && \
update-ca-certificates  && \
cft test run TestBootstrapGitlabVM --stage verify --verbose && \
cft test run TestVPCSC --stage init --verbose && cft test run TestVPCSC --stage apply --verbose && sleep 2m

cft test run TestStandaloneSingleProjectExample --stage init --verbose && \
cft test run TestStandaloneSingleProjectExample --stage apply --verbose && \
cft test run TestSingleProjectSourceCymbalBank --stage verify --verbose
cft test run TestStandaloneSingleProjectExample --stage verify --verbose && \

cft test run TestBootstrap --stage init --verbose && \
cft test run TestBootstrap --stage apply --verbose 

cft test run TestStandaloneSingleProjectConfidentialNodesExample --stage init --verbose && \
cft test run TestStandaloneSingleProjectConfidentialNodesExample --stage apply --verbose && \
cft test run TestStandaloneSingleProjectConfidentialNodesExample --stage verify --verbose && \
cft test run TestSingleProjectSourceCymbalBank --stage verify --verbose

cft test run TestBootstrap --stage init --verbose && \
cft test run TestBootstrap --stage apply --verbose 


cft test run TestStandaloneSingleProjectExample --stage teardown --verbose && \
cft test run TestStandaloneSingleProjectExample --stage teardown --verbose && sleep 10m && \
cft test run TestVPCSC --stage init --verbose && cft test run TestVPCSC --stage teardown --verbose && \
cd test/setup && terraform init && terraform destroy -auto-approve && cd ../../

cft test run TestBootstrap --stage init --verbose && \
cft test run TestBootstrap --stage apply --verbose && \
cft test run TestMultitenant --stage init --verbose && \
cft test run TestMultitenant --stage apply --verbose && \
cft test run TestFleetscope --stage init --verbose && \
cft test run TestFleetscope --stage apply --verbose && \
cft test run TestHPCAppfactory --stage init --verbose && \
cft test run TestHPCAppfactory --stage apply --verbose && \
cft test run TestHPCAppInfra --stage init --verbose && \
cft test run TestHPCAppInfra --stage apply --verbose && \

cft test run TestAppfactory --stage init --verbose && \
cft test run TestAppfactory --stage apply --verbose && \
cft test run TestAppInfra --stage init --verbose && \
cft test run TestAppInfra --stage apply --verbose && \
cft test run TestSourceCymbalShop --stage verify --verbose && \
cft test run TestSourceCymbalBank --stage verify --verbose && \
cft test run TestSourceHelloWorld --stage verify --verbose && \
cft test run TestStandaloneSingleProjectExample --stage teardown --verbose
cft test run TestAppInfra --stage verify --verbose && \
cft test run TestAppfactory --stage verify --verbose && \
cft test run TestFleetscope --stage verify --verbose && \
cft test run TestMultitenant --stage verify --verbose && \

cft test run TestStandaloneSingleProjectExample --stage init --verbose && \
cft test run TestStandaloneSingleProjectExample --stage apply --verbose && \
cft test run TestSingleProjectSourceCymbalBank --stage verify --verbose && \
cft test run TestStandaloneSingleProjectExample --stage verify --verbose && \
cft test run TestAppE2ECymbalBankSingleProject --stage verify --verbose && \

cft test run TestBootstrap --stage verify --verbose && \
cft test run TestMultitenant --stage verify --verbose && \
cft test run TestFleetscope --stage verify --verbose && \
cft test run TestAppfactory --stage verify --verbose && \
cft test run TestAppInfra --stage verify --verbose

cft test run TestHPCAppInfra --stage teardown --verbose &&
cft test run TestHPCAppfactory --stage teardown --verbose && \
cft test run TestFleetscope --stage teardown --verbose && \
cft test run TestMultitenant --stage teardown --verbose && \
cft test run TestBootstrap --stage teardown --verbose && \
cft test run TestVPCSC --stage init --verbose && cft test run TestVPCSC --stage teardown --verbose  && \
cd test/setup && terraform init && terraform destroy -auto-approve && cd ../../


cft test run TestStandaloneSingleProjectExample --stage init --verbose && \
cft test run TestStandaloneSingleProjectExample --stage apply --verbose && \
cft test run TestSingleProjectSourceCymbalBank --stage verify --verbose




