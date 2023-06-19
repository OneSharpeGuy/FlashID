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
Generates a unique Instance ID based on time eLapsed since the Unix Epoch<br> 4B1C-2738-PQNJ<br><br> The first Section is a 4 character Hexidecimal representation of the Days elapsed since 1/1/1970<br> The second section is a representation of the time passed in the current day. <br>The third section is a 4 Character (Adjunct) Alpha string, which will insure that the FlashID is unique across different installations. <br>(Adjunct string will not include and digits or characters used in Hexidecimal notation, [0-9][A-F])<br> <br>Note also, [FlashID] is based on GMT
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

	[string] hidden $Epoch = '1/1/1970'

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
						'Seperator'
						{
							$this.Seperator = $options.$_
						}
						{
							$_ -in 'Epoch','Length','BriefMode','Expanded'
						}
						{
							$this.$key = $options.$_
						}
						{
							$_ -match 'NoSeperator'
						}
						{
							$this.Seperator = ''
						}
						'Initiated'
						{
							$this.Initiated = (Get-Date -Date $options.$_)
						}
						default
						{
							$this.$_ = $options.$_
						}
					}
				}
			}
			else
			{
				switch ($options) {
					{
						$_ -match 'Brief'
					}
					{
						$this.BriefMode = $true
					}
					{
						$_ -match 'NoSeperator'
					}
					{
						$this.Seperator = ''
					}
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

		<#if($this.BriefMode)
    {
      if($this.Length -lt 10)
      {
        $this.Length = 10
      }
    }#>
		#$this.span =(New-TimeSpan -Start (Get-Date $this.Epoch).AddHours((Get-TimeZone).BaseUTCOffset.Hours) -End $this.Initiated.ToUniversalTime())
		#$this.span = (New-TimeSpan -Start (Get-Date $this.Epoch) -End $this.Initiated.ToUniversalTime())
		$this.span = (New-TimeSpan -Start (Get-Date -Date $this.Epoch) -End $this.Zulu)

		$this.HexDate = '{0:X4}' -f $this.span.Days
		#$this.span=$this.Span
		#$this.Adjunct = [FlashID]::Pluck()

		$max = ([math]::Pow(16,($this.length))) - 1
		#Configure a default display set
		$defaultDisplaySet = @('HexDate','PartialDay','Adjunct')

		#Create the default property display set
		$defaultDisplayPropertySet = New-Object -TypeName System.Management.Automation.PSPropertySet -ArgumentList ('DefaultDisplayPropertySet',[string[]]$defaultDisplaySet)
		$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
		$this | Add-Member MemberSet PSStandardMembers $PSStandardMembers

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
				<#
				$tocks = [int64]([math]::Floor(($this.span.TotalDays - $this.span.Days) * $max)) + $i
				if ($Global:LastFlashID.HexDate -eq $this.HexDate) {
					$Otocks = ([int64]"0x$($Global:LastFlashID.PartialDay)")
					if ($Otocks -ge $tocks) {
						$i++
						$tocks = + $i
					}
				}
				#>
				#$this.PartialDay = "{0:X$($this.Length)}" -f [int](($this.span.TotalDays - $this.span.Days) * $max + ($I++))
				$this.PartialDay = "{0:X$($this.Length)}" -f $([int64]([decimal](($this.span.TotalDays - ($this.span.Days)) * $max)) + ($i++))
				if (!$Global:LastFlashID) {
					break
				}

			} while (([int64]"0x$($this.PartialDay)") -le ([int64]"0x$($global:LastFlashID.PartialDay.PadRight($this.Length).Substring(0,$this.Length))"))

			#} while ($this.PartialDay -le $global:LastFlashID.PartialDay)

			if (!($this.BriefMode))
			{
				$this.Adjunct = [FlashID]::Pluck()
			}

			#$this.Summary = $(@($this.HexDate,$this.PartialDay,$this.Adjunct).ForEach{ if ($_) { $_ } } -join $this.Seperator)
			$this.Summary = $this.ToString()

			<#$i++
      if($i -gt 750)
      {
        #break
      }#>
		}
		while ($($this.Summary -eq $($Global:LastFlashID.Summary)))

		#>
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
    [string][FlashID]::new($null)
    [string]([FlashID]::new(@{ Length = '4'; BriefMode = $false; Seperator = ':' }))
    [FlashID]::new($null) | Select-Object * | Format-List
    [string][FlashID]::new(@{ BriefMode = $true })

    [string][FlashID]::new(@{ Length = '1' })
    [FlashID]::Brief()
    [FlashID]::Pop()
    [FlashID]::new()
    [FlashID]::new().ToString()
    [string][FlashID]::new(@{ BriefMode = $true; Epoch = '1/1/1900' })
    [string][FlashID]::new(@{ Epoch = '1/1/1950' })
    [string][FlashID]::new(@{ Epoch = '1/1/2000' })
    [string][FlashID]::new(@{ Epoch = '1/20/2009' })
    [string][FlashID]::new(@{ Epoch = '1/20/2021' })
    [FlashID]::Pop()

    (1..10).ForEach{[FlashID]::bare()}
    (1..10).ForEach{[FlashID]::brief()}
    (1..10).ForEach{[FlashID]::pop()}

    New-ClassHelperMaker "[FlashID]::new()" -Install -ShowFile
#>
<#
#Example Block - Start

			.EXAMPLE
			
			[FlashID]::new()
			
			4C38-A570-UNVJ
			
			
			.EXAMPLE
			
			[FlashID]::Pop()
			4C38-A571-WZVJ
			
			
			.EXAMPLE
			
			[FlashID]::Brief()
			4C38-A570A2
			
			
			.EXAMPLE
			
			[FlashID]::new(@{ BriefMode = $true; Length = 10;Seperator='~' })
			4C38~A570A5AC6B
			
			
			.EXAMPLE
			
			[FlashID]::new()|select *
			
			HexDate    : 4C38
			PartialDay : A571
			Adjunct    : RVNX
			Initiated  : 6/4/2023 11:30:36 AM
			Zulu       : 6/4/2023 3:30:36 PM
			Span       : 19512.15:30:36.0144393
			Lap        : 3
			Length     : 4
			BriefMode  : False
			Expanded   : True
			Summary    : 4C38-A571-RVNX


#Example Block - End
#>


