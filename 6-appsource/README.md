# 6. Application Source Code pipeline

## Purpose
This folder contains necessary configurations for each of the Cymbal Bank applications.

## Usage
Push the contents of the subfolders to each respective application's source code repository. Separately push the source contents of each application, available in the Cymbal Bank repo on [GitHub](https://github.com/GoogleCloudPlatform/bank-of-anthos/tree/main/src).

The application source code repository was created in the [5-appinfra phase](../5-appinfra/modules/cicd-pipeline/main.tf) and can be found in each appliction's respective app admin project. The app admin projects were created by the [application factory pipeline](../4-factory/modules/app-group-baseline/main.tf).
