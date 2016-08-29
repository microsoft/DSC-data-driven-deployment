[![Build status](https://ci.appveyor.com/api/projects/status/6a59vfritv4kbc7d/branch/master?svg=true)](https://ci.appveyor.com/project/Microsoft/DSC-data-driven-deployment/branch/master)

# DSC-data-driven-deployment
Proof-of-concept project illustrating an approach to persisting configuration which allows one to manage and apply DSC configurations in a push driven environment.  Metadata such as parameters and defaults for the configuration are stored as JSON within a database so that it can be programmatically retrieved and deployed. Credentials are also stored securely in the database.  A queuing mechanism exposed as a cmdlet and backed by a table is provided as a means to push configurations on demand.  


## Why?
Provide a central repository to store configurations and credentials, to allow efficient Enterprise provisioning and auditing of configurations.

##Prerequisites
* SQL Server to hold central database repository.
* Windows Server to act as central deployment server.


##Installation
* Log on to SQL Server
* Clone repository with git clone https://github.com/Microsoft/DSC-data-driven-deployment 
	* If Clone location is other than C:\DSC-data-driven-deployment\Modules\ConfigurationHelper.psm1 then update DSCExecutionTask.ps1 and InputDSCConfigurationMetadata.ps1 to reflect the location.
* Open PowerShell Prompt as admin
* Install-module xSQLServer
* Edit [DSCDataDrivenSQLConfiguration.ps1](https://github.com/Microsoft/DSC-data-driven-deployment/blob/dev/scripts/DSCDataDrivenSQLConfiguration.ps1) replace variable values for your environment
* Run DSCDataDrivenSQLConfiguration.ps1
* Open SSMS connect to server.
* Right click Databases and select Deploy-Data-tier Application
* Select dacpac from build directory
* Click Next and Finish
* Log on to Deployment Server
* Copy Project locally to Deployment Server. Same drive letter as SQL or modifications will need to be made.
* Open PowerShell Prompt as admin
* Install-module xSQLServer
* Open [InputDSCConfigurationMetadata.ps1](https://github.com/Microsoft/DSC-data-driven-deployment/blob/dev/scripts/InputDSCConfigurationMetaData.ps1) and modify parmaters at top to meet your environment.
* Execute InputDSCConfigurationMetaData.ps1
* Modify [DSCSQLMetaBuild.ps1](https://github.com/Microsoft/DSC-data-driven-deployment/blob/dev/scripts/DSCSQLMetaBuild.ps1) to match your needs
* Create scheduled [task](https://github.com/Microsoft/DSC-data-driven-deployment/blob/dev/scripts/DSCExecutionTask.ps1) to call script

##Assumptions

* SMB (Port 445) is open between deployment server and servers to receive configuration.
	* xcopy of DSC module is leveraged to move DSC module to remote node
* Configurations provided are using AllowPlainTextPassword for demonstration purposes only.
	* Configurations should be updated to leverage certificates so passwords are not stored plain text.
	* Steps to complete this are detailed [here](https://blogs.msdn.microsoft.com/troy_aults_blog/2016/04/25/sql-dsc-encrypted-configuration/)
	
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