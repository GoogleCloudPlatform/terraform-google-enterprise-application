#!/usr/bin/env python3
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# flake8: noqa

"""
Tools to run Google Cloud Batch API
"""

__author__ = "J Ross Thomson drj@"
__version__ = "0.1.0"

import os
import sys
import kubernetes.client
import dynaconf
import google.auth
import google.auth.transport.requests

from absl import app
from absl import flags
from dynaconf import Dynaconf
from kubernetes.client import Configuration
from kubernetes.client.rest import ApiException

from tabulate import tabulate
from termcolor import colored

"""
We define multiple command line flags:
"""

FLAGS = flags.FLAGS

flags.DEFINE_string("project_id", None, "Google Cloud Project ID, not name")
flags.DEFINE_boolean("create_job", False, "Creates job, otherwise just prints config.")
flags.DEFINE_boolean("list_jobs", False, "If true, list jobs for config.")
flags.DEFINE_string("delete_job", "", "Job name to delete.")
flags.DEFINE_boolean("debug", False, "If true, print debug info.")
flags.DEFINE_string("settings_file", "settings.toml", "TOML/YAML file with settings")
flags.DEFINE_string("args_file", None, "TOML/YAML file with list of container commands")
flags.DEFINE_string("namespace", None, "If set, use this namespace.")

def get_setting(setting, settings):
    if FLAGS.debug:
        print(f"Getting setting {setting}", file=sys.stderr)
    if setting in settings:
        return settings[setting]
    else:
        raise SystemExit(1, f"Setting '{setting}' not found in settings file. Exiting.")


class KubernetesBatchJobs:
    def __init__(self) -> None:
        self.job_prefix = get_setting("job_prefix", settings)

        kubernetes.config.load_kube_config()
        try:
            self.kube_config = Configuration().get_default_copy()
            # use connectgateway
            gke_cluster_endpoint = get_setting("gke_cluster_endpoint", settings)
            print(f"gke-endpoint: {gke_cluster_endpoint}")
            # Obtain Google authentication credentials
            creds, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
            auth_req = google.auth.transport.requests.Request()
            # Refresh the token
            creds.refresh(auth_req)
            # Set the authentication token
            self.kube_config.host = gke_cluster_endpoint
            self.kube_config.api_key_prefix['authorization'] = 'Bearer'
            self.kube_config.api_key['authorization'] = creds.token

        except AttributeError:
            self.kube_config = Configuration()
            self.kube_config.assert_hostname = False
        Configuration.set_default(self.kube_config)
        self.batch_v1 = kubernetes.client.BatchV1Api(
            kubernetes.client.ApiClient(self.kube_config)
        )

        self.project_id = get_setting(setting="project_id", settings=settings)

        if os.environ.get("GOOGLE_CLOUD_PROJECT"):
            self.project_id = os.environ.get("GOOGLE_CLOUD_PROJECT")
        if FLAGS.project_id:
            self.project_id = FLAGS.project_id

    def create_job_request(self):
        container1 = self._create_container()
        volumes1 = self._create_volumes()
        mounts1 = self._create_volume_mounts()
        container1.volume_mounts = mounts1
        pod_template1 = self._create_pod_template(container1, volumes1)

        # Create JobSpec
        parallelism = get_setting("parallelism", settings)
        suspend = get_setting("suspend", settings)

        job_spec = kubernetes.client.V1JobSpec(
            template=pod_template1, suspend=suspend, parallelism=parallelism
        )

        completion_mode = get_setting("completion_mode", settings)
        if completion_mode == "Indexed":
            completions = get_setting("completions", settings)
            job_spec.completion_mode = completion_mode
            job_spec.completions = completions
            job_spec.backoff_limit = get_setting("backoff_limit", settings)
        # Create Job ObjectMetadata
        jobspec_metadata = kubernetes.client.V1ObjectMeta(
            generate_name=self.job_prefix,
            annotations=get_setting("job_annotations", settings),
        )
        # Create a V1Job object
        job_request = kubernetes.client.V1Job(
            api_version="batch/v1",
            kind="Job",
            spec=job_spec,
            metadata=jobspec_metadata,
        )
        return job_request

    def _create_volume_mounts(self):
        # Create Volume Mounts
        # Get volume settings
        volume_mount1 = kubernetes.client.V1VolumeMount(
            name="gcs-fuse-csi-ephemeral",
            mount_path=get_setting("mount_path", settings),
        )
        return [volume_mount1]

    # Create Volumes
    def _create_volumes(self):
        volume_attributes1 = {"bucketName": get_setting("bucketName", settings)}
        volume_source1 = kubernetes.client.V1CSIVolumeSource(
            driver=get_setting("driver", settings), volume_attributes=volume_attributes1
        )
        volume1 = kubernetes.client.V1Volume(
            name="gcs-fuse-csi-ephemeral", csi=volume_source1
        )
        volumes = [volume1]
        return volumes

    def _create_container(self):
        # Get container settings
        container_settings = get_setting("container", settings)
        image = get_setting("image_uri", container_settings)

        # Create Env Vars
        env1 = kubernetes.client.V1EnvVar(
            name="JOB_NAME",
            value_from=kubernetes.client.V1EnvVarSource(
                field_ref=kubernetes.client.V1ObjectFieldSelector(
                    field_path="metadata.name"
                )
            ),
        )
        env2 = kubernetes.client.V1EnvVar(name="JOB_PREFIX", value=self.job_prefix)

        # Create container

        container = kubernetes.client.V1Container(
            name=self.job_prefix,
            image=image,
            command=get_setting("command", settings),
            args=get_setting("args", settings),
            resources=kubernetes.client.V1ResourceRequirements(
                limits=get_setting("limits", settings),
            ),
            env=[env1, env2],
        )
        return container

    def _create_object_metadata(self):
        pass

    def _create_pod_template(self, container1, volumes):
        # Create Pod Template and PodSpec
        service_account_name = get_setting("service_account_name", settings)
        node_selector = get_setting("node_selector", settings)
        pod_annotations = get_setting("pod_annotations", settings)

        podspec_metadata = kubernetes.client.V1ObjectMeta(
            name=self.job_prefix, annotations=pod_annotations
        )
        pod_spec = kubernetes.client.V1PodSpec(
            containers=[container1],
            restart_policy="Never",
            node_selector=node_selector,
            volumes=volumes,
            service_account_name=service_account_name,
        )
        # Create PodTemplateSpec
        pod_template = kubernetes.client.V1PodTemplateSpec(
            metadata=podspec_metadata, spec=pod_spec
        )
        return pod_template

    #
    # Here is where the jobs is actually created
    #
    def create_job(self, create_request):
        # Create the job in the cluster
        namespace = get_setting("namespace", settings)
        api_response = self.batch_v1.create_namespaced_job(
            namespace=namespace,
            body=create_request,
        )
        # print(api_response.metadata.labels["job-name"],file=sys.stderr)
        print(
            f"Job {api_response.metadata.labels['job-name']} created. Timestamp='{api_response.metadata.creation_timestamp}'"
        )

    def delete_job(self, job_name):
        namespace = get_setting("namespace", settings)
        try:
            api_response = self.batch_v1.delete_namespaced_job(job_name, namespace)
            print(api_response, file=sys.stderr)
        except ApiException as e:
            print("Exception when calling BatchV1Api->list_namespaced_job: %s\n" % e)

    def list_jobs(self):
        namespace = get_setting("namespace", settings)
        try:
            api_response = self.batch_v1.list_namespaced_job(namespace)
        except ApiException as e:
            print("Exception when calling BatchV1Api->list_namespaced_job: %s\n" % e)

        if FLAGS.debug:
            print(api_response, file=sys.stderr)

        headers = ["Job Name", "Active", "Succeeded", "Failed", "Completed Index"]
        rows = []
        for item in api_response.items:
            succeeded = item.status.succeeded
            failed = item.status.failed
            completed = item.status.completed_indexes
            active = item.status.active
            rows.append(
                [
                    colored(item.metadata.labels["job-name"], "blue"),
                    colored(active, "cyan"),
                    colored(succeeded, "green"),
                    colored(failed, "red"),
                    colored(completed, "yellow"),
                ]
            )

        print(tabulate(rows, headers, tablefmt="grid"))


def main(argv):
    """ """
    jobs = None
    global settings

    settings = Dynaconf(
        envvar_prefix="GKEBATCH",
        settings_files=[FLAGS.settings_file],
        environments=True,
    )

    # Namespace, take CLI argument over other paths
    if FLAGS.namespace:
        print(f"Setting Namespace: {FLAGS.namespace}", file=sys.stderr)
        settings["NAMESPACE"] = FLAGS.namespace

    # Create Cloud Batch jobs object, should probably be default and not require this.
    if get_setting("platform", settings) == "kubernetes":
        jobs = KubernetesBatchJobs()
    else:
        # Create Cloud Batch jobs object
        print("platform must be set in the settings file. Exiting.")

    # Delete job. JobID must be passed.
    if FLAGS.delete_job:
        print("Deleting job", file=sys.stderr)
        jobs.delete_job(FLAGS.delete_job)
        exit()

    # Prints list of jobs, in queue, running or complteted.
    if FLAGS.list_jobs:
        print("Listing jobs", file=sys.stderr)
        jobs.list_jobs()
        exit()

    # Prints config file info
    if FLAGS.debug:
        print(dynaconf.inspect_settings(settings))
        exit()

    if FLAGS.args_file:
        settings.load_file(path=FLAGS.args_file)  # list or `;/,` separated allowed
        for arg in settings.ARGS:
            print(f"This is the arg: {arg}")
            settings.command = arg
            jobs = KubernetesBatchJobs()
            print(jobs.create_job(jobs.create_job_request()), file=sys.stderr)
        exit()

    if FLAGS.create_job:
        # Create the job
        print(jobs.create_job(jobs.create_job_request()), file=sys.stderr)
    else:
        print(jobs.create_job_request(), file=sys.stderr)


if __name__ == "__main__":
    """ This is executed when run from the command line """
    app.run(main)
