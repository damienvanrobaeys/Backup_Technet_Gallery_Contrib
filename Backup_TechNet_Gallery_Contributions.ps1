[CmdletBinding()]
Param(
		[Parameter(Mandatory=$false)]	
		[string]$User_Name,
		[Parameter(Mandatory=$false)]	
		[string]$Backup_output_Folder,
		[Parameter(Mandatory=$false)]			
		[string]$Profile_Link		
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
		

	ForEach($Contrib in $Contrib_Array.link)
		{
			$Contrib_Sring = [string]$Contrib
			$Contrib_To_Get = $Basic_Technet_Link + $Contrib_Sring.split(':')[1]
			$Parse_Contrib_Link = Invoke-WebRequest -Uri $Contrib_To_Get | select *
			
			$Parse_Contrib_Body = $Parse_Contrib_Link.ParsedHtml.body
			$Get_Contrib_Title = ($Parse_Contrib_Body.getElementsByClassName("projectTitle")) |  select -expand innertext
			$Get_Contrib_Summary = ($Parse_Contrib_Body.getElementsByClassName("projectSummary")) |  select -expand innerHTML
			$Get_Contrib_Summary_HTML = ($Parse_Contrib_Body.getElementsByClassName("projectSummary")) |  select -expand outerHTML
			
			$Get_Contrib_Link = $Parse_Contrib_Body.getElementsByClassName("button") | select -expand pathname
			$Get_Contrib_Download_File = $Parse_Contrib_Body.getElementsByClassName("button") | select -expand textContent -ErrorAction silentlycontinue
			
			$full_link = "$Basic_Technet_Link/$Get_Contrib_Link"

			$Get_Contrib_Title = $Get_Contrib_Title -Replace'[\/:*?"<>|()]'," " 
			$Get_Contrib_Title2 = $Get_Contrib_Title.replace("[","").replace("]","").replace(" ","_")
			write-host ""
			write-host "Working of the contribution $Get_Contrib_Title2" -foreground "cyan"
			
			$Contrib_Folder = "$Backup_output_Folder\$Get_Contrib_Title2" 				
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
		}
	}