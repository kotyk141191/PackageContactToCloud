# PackageContactToCloud

A description of this package.


Before using package you need required user contacts permision and iCloud container set i your app

1: search and add to Info.plist :
"Privacy - Contacts Usage Description" and describe message tha you want show to your user

2. in your ProjetName->Targets->Sign&Capabilities add "iCloud" capability, check box "iCloudKit" and create your container in the field bellow naming as you bundle identifier. Than click "CloudKit console" and logged in your apple account to create and set the container

