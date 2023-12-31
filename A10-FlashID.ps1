#requires -Version 5.0
<#
Comments Inclosed in an HTML Comment block <!--  --> 
with the member name in ANSI quotes <!-- [Member] --> 
are used by the New-ClassHelperMaker command to auto-generate  FlashID.html
#>
<#
<!-- [Synopsis]
Generates a unique Instance ID
-->

<!-- [Description]
Generates a unique Instance ID based on time elapsed since the Unix Epoch<br><br>
The first Section is a 4 character Hexidecimal representation of the Days elapsed since 1/1/1970<br>
The second section is a representation of the time passed in the current day.
<br>The third section is a 4 Character (Adjunct) Alpha string, which will insure that the FlashID is unique across different installations. 
<br>(Adjunct string will not include and digits or characters used in Hexidecimal notation, [0-9][A-F])<br>
<br>Note also, [FlashID] is based on GMT
-->

#>
<# Methods

<!-- [Brief]
Default FlashID without Adjunct Section
<pre>
*Note: Because Brief Mode is a representaion of time passed in a day,<br>
       unique FlashID can not be guaranteed in brief mode with a fast processor
</pre>
-->
#>

class FlashID{

	[string]
	#4 Character Random Alpha String
	$HexDate

	[string]
	#Part of day elapsed since midnight
	$PartialDay

	[string]
	#4 Character Random Alpha String
	$Adjunct

	[datetime]
	#Date and Time the FlashID was created
	$Initiated
	[datetime]
	#Date and Time the FlashID was created, GMT
	$Zulu
	[timespan]
	#TimeSpan (Since Epoch)
	$Span

	[double]
	#Milliseconds Elapsed in creation
	$Lap

	[string] hidden $Seperator = '-'
	[ValidateRange(1,10)]
	[int]
	#Number of Characters in PartialDay section
	$Length = 4
	[switch]
	#	Supress Adjunct section
	$BriefMode
	[switch]
	#Include Adjunct String
	$Expanded
	[string]
	#String representation of FlashID
	$Summary
	

	[string] hidden $Epoch = (get-date '1/1/1970').ToUniversalTime()

	[string] ToString ()
	{
		$stack = @($this.HexDate,$this.PartialDay)
		if ($this.Adjunct)
		{
			$stack += $this.Adjunct
		}
		return $stack -join $this.Seperator
	}
	[string] hidden static juxtapose ($fudge)
	{
		return @($fudge.HexDate,$fudge.PartialDay,$fudge.Adjunct) -join '-'
	}
	[string] hidden static TruePluck ([int]$count)
	{
		#$(((@(49..57) + @(65..90) |
		return -join $(@(71..90 |
				Get-Random -Count ($count * 2)).ForEach{ [char]$_ } |
			sort { Get-Random } | Get-Random -Count $count)
	}
	[string]
	# Generates a random alpha numeric string
	hidden static Pluck ([int]$count)
	{
		return [FlashID]::TruePluck($count)
	}
	[string] hidden static Pluck ()
	{
		return [FlashID]::TruePluck(4)
	}
	[string]
	#	Returns string representation of FlashID
	static Pop ()
	{
		return [FlashID]::new()
	}
	[string] static Pop ([hashtable]$options)
	{
		return [FlashID]::new($options)
	}
	[FlashID]
	<#
        Default FlashID without Adjunct Section
        * Note: Because Brief Mode is a representaion of time passed in a day, 
          unique FlashID can not be guaranteed in brief mode with a fast processor
    #>
	static Brief ()
	{
		#$B=[FlashID]::new('Brief')
		#return  $(@($B.HexDate,$B.PartialDay,$B.Adjunct).ForEach{ if ($_) { $_ } } -join $B.Seperator)
		return ([FlashID]::new('Brief'))
	}
	[string]
	#12 Character FlashID without seperators
	static Bare ()
	{

		return [FlashID]::new(@{
				'NoSeperators' = $true
			})
	}
	hidden [string] static qpop ()
	{
		return [FlashID]::Brief()
	}
	[void] static help ()
	{
		(Get-ChildItem (Join-Path -Path ($env:PSModulePath -split ';' -match $env:USERNAME) -ChildPath 'OSGPSX') -Recurse | Where-Object -Property Name -EQ -Value 'FlashID.html').FullName | Invoke-Item
	}
	hidden
#Make the Default Display look better
 ButchUp () {

		#Remove-TypeData 'OSG.FlashID'
		#Remove-TypeDate 'FlashID'
		$TTN=$this.GetType().Name
		$this.psTypeNames.Add($TTN)
		if (!(Get-TypeData -TypeName $TTN)) {
			$DPS=@('HexDate','PartialDay','Adjunct','Initiated')
			Update-TypeData -TypeName $TTN -DefaultDisplayPropertySet $DPS
		}
		if (!(Get-FormatData -TypeName $TTN -PowerShellVersion $global:PSVersionTable.PSVersion)) {
			$FormatFile = Join-Path $PSScriptRoot ('{0}.Format.ps1Xml' -f 'FlashID')
			if (Test-Path $FormatFile) {
				Update-FormatData $FormatFile
			}
		}

	}
	hidden Init ($options)
	{

		$this.Initiated = (Get-Date)
		$this.Zulu = $this.Initiated.ToUniversalTime()
		$hold = $this.length
		if ($options)
		{
			if ($options.GetType().Name -eq 'Hashtable')
			{
				foreach ($key in $options.Keys)
				{
					switch ($key) {
						'Seperator' { $this.Seperator = $options.$_ }
						'Epoch' {$this.Epoch = (get-date $options.$_).ToUniversalTime()}
						{ $_ -in 'Length','BriefMode','Expanded' } { $this.$key = $options.$_ }
						{$_ -match 'NoSeperator' } { $this.Seperator = '' }
						'Initiated' { $this.Initiated = (Get-Date -Date $options.$_) }
						default { $this.$_ = $options.$_ }
					}
				}
			}
			else
			{
				switch ($options) {
					{ $_ -match 'Brief' } { $this.BriefMode = $true }
					{
						$_ -match 'NoSeperator' } { $this.Seperator = '' }
				}
			}
		}

		if ($this.BriefMode) { $this.Expanded = $false }
		$this.Expanded = !$this.BriefMode
		#if ($this.Expanded) { $this.BriefMode = $false }
		if (((!$this.Expanded) -or $this.BriefMode))
		{

			if ($this.length -eq $hold)
			{
				if ($this.length -lt 4)
				{
					$this.length = 4
				}
				if ($this.length -eq 4) {
					$this.length = 6
				}
			}
		}

		$this.span = (New-TimeSpan -Start (Get-Date -Date $this.Epoch) -End $this.Zulu)

		$this.HexDate = '{0:X4}' -f $this.span.Days

		$max = ([math]::Pow(16,($this.length))) - 1
		#Configure a default display set
		<#
		$defaultDisplaySet = @('HexDate','PartialDay','Adjunct')

		#Create the default property display set
		$defaultDisplayPropertySet = New-Object -TypeName System.Management.Automation.PSPropertySet -ArgumentList ('DefaultDisplayPropertySet',[string[]]$defaultDisplaySet)
		$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
		$this | Add-Member MemberSet PSStandardMembers $PSStandardMembers
		#>
		$this.ButchUp()
		$i = 0
		do
		{
			if ($this.BriefMode) {
				if ($i -gt 2)
				{
					#Start-Sleep -Milliseconds 10
				}
			}
			do {

				$this.PartialDay = "{0:X$($this.Length)}" -f $([int64]([decimal](($this.span.TotalDays - ($this.span.Days)) * $max)) + ($i++))
				if (!$Global:LastFlashID) {
					break
				}

			} while ($(if (($this.Initiated).Date -eq ($Global:LastFlashID.Initiated).Date) {
						([int64]"0x$($this.PartialDay)") -le ([int64]"0x$($global:LastFlashID.PartialDay.PadRight($this.Length).Substring(0,$this.Length))")
					} else {
						($this.Summary -eq $Global:LastFlashID.Summary)
					}
				)
			)

			if (!($this.BriefMode))
			{
				$this.Adjunct = [FlashID]::Pluck()
			}

			$this.Summary = $this.ToString()

		}
		while ($($this.Summary -eq $($Global:LastFlashID.Summary)))

		$this.Lap = '{0:g3}' -f (New-TimeSpan -Start $this.Initiated).TotalMilliseconds
		$Global:LastFlashID = $this

	}
	FlashID ()
	{
		$this.Init($null)
	}
	FlashID ($options)
	{
		$this.Init($options)
	}
}
<#
[FlashID]::new()
[FlashID]::new($null)

[FlashID]::Brief()
[FlashID]::Pop()
[FlashID]::Bare()



[FlashID]::new().ToString()
[string][FlashID]::new()

[FlashID]::new(@{ BriefMode = $true })
[FlashID]::new(@{ Length = '3'; BriefMode = $false; Seperator = ':' })
[FlashID]::new(@{ Length = '1' })


(1..10).ForEach{[FlashID]::New()}

[FlashID]::new() | Format-Table
[FlashID]::new() | Format-List
[FlashID]::new() | Select-Object * | Format-List



[FlashID]::new(@{ BriefMode = $true; Epoch = '1/1/1900' })
[FlashID]::new(@{ Epoch = '1/1/1950' })
[FlashID]::new(@{ Epoch = '1/1/2000' })
[FlashID]::new(@{ Epoch = '1/20/2009' })
[FlashID]::new(@{ Epoch = '1/20/2021' })

    
#>
#New-ClassHelperMaker "FlashID" -Install -ShowFile
<#
#Example Block - Start

.EXAMPLE

[FlashID]::new()

4C47-6B62-WXTZ


.EXAMPLE

[FlashID]::new($null)
4C47-6B63-RNYQ


.EXAMPLE

[FlashID]::Brief()
4C47-6B6295


.EXAMPLE

[FlashID]::Pop()
4C47-6B63-QWYI


.EXAMPLE

[FlashID]::Bare()
4C476B64QUOI


.EXAMPLE

[FlashID]::new().ToString()
4C47-6B65-HXZM


.EXAMPLE

[string][FlashID]::new()
4C47-6B66-LVYQ


.EXAMPLE

[FlashID]::new(@{ BriefMode = $true })
4C47-6B62AE


.EXAMPLE

[FlashID]::new(@{ Length = '3'; BriefMode = $false; Seperator = ':' })
4C47:6B7:SRZV


.EXAMPLE

[FlashID]::new(@{ Length = '1' })
4C47-7-IYUJ


.EXAMPLE

(1..10).ForEach{[FlashID]::New()}
4C47-6B62-PQNI
4C47-6B63-MYLZ
4C47-6B64-IJGV
4C47-6B65-VHGK
4C47-6B66-LTVM
4C47-6B67-HPYL
4C47-6B68-NKOG
4C47-6B69-LMPY
4C47-6B6A-JQHW
4C47-6B6B-HINY


.EXAMPLE

[FlashID]::new() | Format-Table



HexDate PartialDay Adjunct Initiated            
------- ---------- ------- ---------            
4C47    6B6C       ZYHV    6/19/2023 11:04:02 AM




.EXAMPLE

[FlashID]::new() | Format-List


HexDate    : 4C47
PartialDay : 6B6D
Adjunct    : RIMH
Initiated  : 6/19/2023 11:04:02 AM





.EXAMPLE

[FlashID]::new() | Select-Object * | Format-List


HexDate    : 4C47
PartialDay : 6B6E
Adjunct    : JRSO
Initiated  : 6/19/2023 11:04:02 AM
Zulu       : 6/19/2023 3:04:02 PM
Span       : 19527.10:04:02.8181256
Lap        : 5
Length     : 4
BriefMode  : False
Expanded   : True
Summary    : 4C47-6B6E-JRSO





.EXAMPLE

[FlashID]::new(@{ BriefMode = $true; Epoch = '1/1/1900' })

B026-6B62DE


.EXAMPLE

[FlashID]::new(@{ Epoch = '1/1/1950' })
68D0-6B63-QVKG


.EXAMPLE

[FlashID]::new(@{ Epoch = '1/1/2000' })
217A-6B64-YMHX


.EXAMPLE

[FlashID]::new(@{ Epoch = '1/20/2009' })
148F-6B65-MYZR


.EXAMPLE

[FlashID]::new(@{ Epoch = '1/20/2021' })
0370-6B66-SJIK



#Example Block - End
#>

