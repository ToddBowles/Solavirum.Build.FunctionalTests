The functional tests are typically run with a batch file containing the following command (with actual values in place of the question marks):

'''
AWS_KEY=?
AWS_SECRET=?
AWS_REGION=?
AWS_BUCKET=?
BUILD_IDENTIFIER=? 
PATH_TO_INSTALLER=?

powershell -ExecutionPolicy remotesigned -File scripts\functional-tests.ps1 %AWS_KEY% %AWS_SECRET% %AWS_REGION% %AWS_BUCKET% %BUILD_IDENTIFIER% "%PATH_TO_INSTALLER%" "%~dp0"
'''

The scripts assume the existence of a tools directory in parallel with the scripts directory (which is not in this repository).