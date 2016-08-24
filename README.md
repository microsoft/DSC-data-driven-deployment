[![Build status](https://ci.appveyor.com/api/projects/status/6a59vfritv4kbc7d/branch/master?svg=true)](https://ci.appveyor.com/project/Microsoft/DSC-data-driven-deployment/branch/master)

# DSC-data-driven-deployment
This is a Proof of Concept Project on how a database solution can be utilized to manage DSC configurations. Metadata for the configuration is stored in JSON within the database so that it can be easily retrieved and deployed. Credentials are also stored securely in the database. The project consists of a database schema and a PowerShell module which has a series of functions.


## Why?
Provide a central repository to store configurations and credentials, to allow efficient Enterprise provisioning and auditing of configurations.

##Prerequisites
* SQL Server to hold central database repository.
* Windows Server to act as central deployment server.

##Installation
* Clone repository with git clone https://github.com/Microsoft/DSC-data-driven-deployment 
	* If Clone location is other than G:\DSC-data-driven-deployment\Modules\ConfigurationHelper.psm1 then update DSCExecutionTask.ps1 and InputDSCConfigExamples.ps1 to reflect the location.
* Open SSMS Right click Databases and select Deploy-Data-tier Application
* Select dacpac from build directory
* Click Next and Finish
* Setup Environment utilizing [Examples](https://github.com/Microsoft/DSC-data-driven-deployment/blob/dev/scripts/InputDSCConfigExamples.ps1)
* Modify [Configuration](https://github.com/Microsoft/DSC-data-driven-deployment/blob/dev/scripts/DSCStandAloneJSON_CalledbyDSCExecution.ps1) to match your needs
* Create scheduled [task](https://github.com/Microsoft/DSC-data-driven-deployment/blob/dev/scripts/DSCExecutionTask.ps1) to call script

## Contribute

There are many ways to contribute.

* [Submit bugs](https://github.com/Microsoft/DSC-data-driven-deployment/issues) and help us verify fixes as they are checked in.
* Review [code changes](https://github.com/Microsoft/DSC-data-driven-deployment/pulls).
* Contribute bug fixes and features.

For code contributions, you will need to complete a Contributor License Agreement (CLA). Briefly, this agreement testifies that you grant us permission to use the submitted change according to the terms of the project's license, and that the work being submitted is under the appropriate copyright.

Please submit a Contributor License Agreement (CLA) before submitting a pull request. You may visit <https://cla.microsoft.com> to sign digitally. Alternatively, download the agreement [Microsoft Contribution License Agreement.pdf](https://cla.microsoft.com/cladoc/microsoft-contribution-license-agreement.pdf), sign, scan, and email it back to <cla@microsoft.com>. Be sure to include your GitHub user name along with the agreement. Once we have received the signed CLA, we'll review the request.

##Code of Conduct 
This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
## License

This project is [licensed under the MIT License](LICENSE).