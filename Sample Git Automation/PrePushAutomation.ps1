# The powershell script is called from the pre-push githook. 
# https://git-scm.com/docs/githooks#_pre_push
# pre-push will call this powershell with three parameters:
# * name of the target remote repository, 
# * location of the target remote repository, 
# * Information about what is to be pushed ini the form
#    <local ref> SP <local object name> SP <remote ref> SP <remote object name> LF\



[CmdletBinding()]
param (
    #Name of the Destination Remote
    [string] $RemoteName,
    #Location of the Destination Remote
    [string] $RemoteDestination,
    #Information about what is to be pushed
    [string] $PushInfo
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


# function that parses the Information pushed into an object.
function ParseInfo ($Info) {
    $Info2 = $Info -split "`n"
    $ParsedInfo = @()
    foreach ($line in $Info2) {
        $breakLine = $line -split " "
        $ParsedInfo += [PSCustomObject]@{
            LocalRef     = $breakLine[0]
            LocalObject  = $breakLine[1]
            RemoteRef    = $breakLine[2]
            RemoteObject = $breakLine[3]
        }
    }
    return $ParsedInfo
}


# get last commit info
$LastCommit = @(git log --pretty=oneline --decorate)[0]

# check last commit for tag existance. Quit and continue push if it doesnt exist
if ($LastCommit -notmatch "tag: (?'tag'.*?)[,|)]") {
    Write-Host  "Last commit does not contain a tag. Push to remote started."
    exit 0
}
$Tag = $Matches.tag;

#check if tags are being pushed. Quits if they are not
$TagFound = $false
foreach ($Info in $ParsedPushInfo) {
    if ($Info.LocalRef -match $Tag) {
        $TagFound = $true
        break
    }
}

if (-not $TagFound) {
    [void][System.Windows.Forms.MessageBox]::Show("Tags are not being pushed, tag already exists in remote or tag doesn't have a message.", 'Abort Operation')
    "git config --global push.followTags true"
   exit -1
}
#https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
#https://regex101.com/r/Ly7O1x/3/
$SemanticVersionRegex = "^v(?'major'0|[1-9]\d*)\.(?'minor'0|[1-9]\d*)\.(?'patch'0|[1-9]\d*)(?:-(?'prerelease'(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?'buildmetadata'[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$"
# checks if the tag has been properly formated
if ($Tag -notmatch $SemanticVersionRegex ) {
    [void][System.Windows.Forms.MessageBox]::Show("Improperly formated valid tag. [$Tag]`rPlease format this way: v#.#.#{-prerelease}{+buildmetadata}`rNo files were copied and push to remote was aborted", 'Abort Operation')
    exit -1
}

