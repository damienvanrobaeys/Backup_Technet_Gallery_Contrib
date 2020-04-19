[CmdletBinding()]
Param(
		[Parameter(Mandatory=$false)]	
		[string]$User_Name,
		[Parameter(Mandatory=$false)]	
		[string]$Backup_output_Folder,
		[Parameter(Mandatory=$false)]			
		[string]$Profile_Link,
		[Switch]$MigrateToGitHub				
	 )	

$Basic_Technet_Link = "https://gallery.technet.microsoft.com"
If($Profile_Link -ne "")
	{
		$link = $Profile_Link
	}
Else
	{
		If($User_Name -eq "")
			{
				$User_Name = read-host "Type the name of the user"

			}	
		$link = $Basic_Technet_Link + '/site/search?f%5B0%5D.Type=User&f%5B0%5D.Value=' + $User_Name	
	}
$User_Name_Complete = $User_Name
$User_Name = $User_Name.Replace(" ","%20")	
	  
If($Backup_output_Folder -eq "")
	{
		$Backup_output_Folder = read-host "Type the path where to backup your contributions"
	}

If($MigrateToGitHub)
	{
		$GitHub_SecureToken = Read-Host -assecurestring "Type your GitHub token"						
	}	
	
$parse_profile = Invoke-WebRequest -Uri $link | select *
If($parse_profile.StatusDescription -eq "OK")
{
	$Number_of_contributions = ($parse_profile.ParsedHtml.body.getElementsByClassName("browseBreadcrumb") | select -expand textContent).split("results")[0]
	$Get_Last_Character = $parse_profile.ParsedHtml.body.getElementsByClassName("Link") | Where {$_.innertext -like "*Last*"} 

	write-host ""

	If($Number_of_contributions -eq 0)
		{
			write-host "There is no contribution from $User_Name_Complete"	
		}

	If($Number_of_contributions -gt 1)
		{
			write-host "There are $Number_of_contributions contributions from $User_Name_Complete"
		}Else{
			write-host "There is $Number_of_contributions contribution from $User_Name_Complete"		
		}	

	If($Get_Last_Character -eq $null)
		{
			$Parse_Current_Page = Invoke-WebRequest -Uri $link | select *
			$Current_Page_Content = $Parse_Current_Page.links | Foreach {$_.href }
			$Current_Page_Links = $Current_Page_Content | Select-String -Pattern 'about:' | Select-String -Pattern "/site/" -NotMatch  | Select-String -Pattern "about:blank#" -NotMatch | Select-String -Pattern "about:/Account/" -NotMatch	
			$Contrib_Obj = New-Object PSObject
			$Contrib_Obj | Add-Member NoteProperty -Name "Link" -Value $Current_Page_Links	
			$Contrib_Array += $Contrib_Obj	
		}	
	Else
		{
			$Get_Last_Page = ($Get_Last_Character  | select -expand href).Split("=")[3] 	
			$Contrib_Array = @()
			for ($i=1; $i -le $Get_Last_Page; $i++)
			{
				$Current_Link = $link +  "&pageIndex=$i"	
				$Parse_Current_Page = Invoke-WebRequest -Uri $Current_Link | select *
				$Current_Page_Content = $Parse_Current_Page.links | Foreach {$_.href }
				$Current_Page_Links = $Current_Page_Content | Select-String -Pattern 'about:' | Select-String -Pattern "/site/" -NotMatch  | Select-String -Pattern "about:blank#" -NotMatch | Select-String -Pattern "about:/Account/" -NotMatch	
				$Contrib_Obj = New-Object PSObject
				$Contrib_Obj | Add-Member NoteProperty -Name "Link" -Value $Current_Page_Links	
				$Contrib_Array += $Contrib_Obj	
			}
		}

	If($MigrateToGitHub)
	{
		If (!(Get-Module -listavailable | where {$_.name -like "*PowerShellForGitHub *"})) 
			{ 
				Install-Module PowerShellForGitHub  -ErrorAction SilentlyContinue 
			} 
		Else 
			{ 
				Import-Module PowerShellForGitHub  -ErrorAction SilentlyContinue 			
			} 	
		
		write-host ""
		write-host "Connecting on your GitHub account" -foreground "cyan"		
		$cred = New-Object System.Management.Automation.PSCredential "username is ignored", $GitHub_SecureToken
		Try
			{
				Set-GitHubAuthentication -Credential $cred -SessionOnly | out-null
				$GitHub_OwnerName = (Get-GitHubUser -Current).login	| out-null
				write-host "Connexion on your GitHub account is OK" -foreground "cyan"					
			}
		Catch
			{}		
	}
		
	for ($i = 0; $i -lt $Number_of_contributions;)
	{ 
		ForEach($Contrib in $Contrib_Array.link)
			{
					$i++
					$Percent_Progress = [math]::Round($i / $Number_of_contributions * 100)
					Write-Progress -Activity "Backup Technet Gallery contributions" -status "Contribution $i / $Number_of_contributions - $Percent_Progress %"
					
					$Contrib_Sring = [string]$Contrib
					$Contrib_To_Get = $Basic_Technet_Link + $Contrib_Sring.split(':')[1]
					$Parse_Contrib_Link = Invoke-WebRequest -Uri $Contrib_To_Get | select *
					
					$Parse_Contrib_Body = $Parse_Contrib_Link.ParsedHtml.body
					$Get_Contrib_Title_NoFormat = ($Parse_Contrib_Body.getElementsByClassName("projectTitle")) |  select -expand innertext
					$Get_Contrib_Summary = ($Parse_Contrib_Body.getElementsByClassName("projectSummary")) |  select -expand innerHTML
					$Get_Contrib_Summary_HTML = ($Parse_Contrib_Body.getElementsByClassName("projectSummary")) |  select -expand outerHTML
					
					$Get_Contrib_Link = $Parse_Contrib_Body.getElementsByClassName("button") | select -expand pathname
					$Get_Contrib_Download_File = $Parse_Contrib_Body.getElementsByClassName("button") | select -expand textContent -ErrorAction silentlycontinue
					
					$full_link = "$Basic_Technet_Link/$Get_Contrib_Link"
					
					$Get_Contrib_Title = ($Get_Contrib_Title_NoFormat -Replace'[\/:*?"<>|()]'," ").replace("]","").replace(" ","_")
					
					write-host ""
					write-host "Working on the contribution $Get_Contrib_Title" -foreground "cyan"
					
					$Contrib_Folder = "$Backup_output_Folder\$Get_Contrib_Title" 				
					
					New-Item $Contrib_Folder -Type Directory -Force | out-null

					write-host "Folder $Contrib_Folder has been created" 
						
					$Contrib_File_Summary = "$Contrib_Folder\Summary.txt"
					$Get_Contrib_Summary | out-file $Contrib_File_Summary				
					
					$Contrib_File_Summary_HTML = "$Contrib_Folder\Summary_HTML.txt"
					$Get_Contrib_Summary_HTML | out-file $Contrib_File_Summary_HTML				
					write-host "A summary.txt file has been created in the folder with the description of the contribution."

					If($Get_Contrib_Download_File -ne $null)
						{
							Invoke-WebRequest -Uri $full_link -OutFile "$Contrib_Folder\$Get_Contrib_Download_File"		
							write-host "The file $Get_Contrib_Download_File has been downloaded in the folder"
						}
					Else
						{
							write-host "There is no uploaded file to backup"			
						}
			
					If($MigrateToGitHub)
						{
							$Contrib_File_Mardown = "$Contrib_Folder\Readme.md"
							$Get_Contrib_Summary | out-file $Contrib_File_Mardown	
						
							$GitHub_RepositoryName = $Get_Contrib_Title_NoFormat
							$Create_Repo = New-GitHubRepository  -RepositoryName $Get_Contrib_Title_NoFormat
							$Repo_URL = $Create_Repo.url
							write-host "A repository $Get_Contrib_Title_NoFormat has been created on your GitHub"

							$File_To_Upload = "$Contrib_Folder\$Get_Contrib_Download_File"
							$Get_File_Name = (Get-ChildItem $File_To_Upload).name					
							$Encoded_File = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes("$File_To_Upload"));							
							$Encoded_ReadMe_File = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes("$Contrib_File_Mardown"));							
							
							write-host "The file $Get_File_Name has been encoded to base 64"

$MyFile_JSON = @"
{
  "message": "",
  "content": "$Encoded_File"
}
"@

$MyReadMe_JSON = @"
{
  "message": "",
  "content": "$Encoded_ReadMe_File"
}
"@

						Try
							{
								Invoke-GHRestMethod -UriFragment "$Repo_URL/contents/$Get_File_Name" -Method PUT -Body $MyFile_JSON | out-null
								Invoke-GHRestMethod -UriFragment "$Repo_URL/contents/Readme.md" -Method PUT -Body $MyReadMe_JSON | out-null								
								write-host "The file $Get_File_Name will be uploaded to $GitHub_OwnerName/$GitHub_RepositoryName"									
								write-host "The file $Get_File_Name has been successfully uploaded to GitHub"				
							}
						Catch
							{
								write-warning "The file $Get_File_Name has been successfully uploaded to GitHub"								
							}						
					}		
			}
		}
	}
	
