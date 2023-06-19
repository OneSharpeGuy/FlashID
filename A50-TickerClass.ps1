class Stepper{

	[string]$Occasion
	[datetime]$Intiated = (Get-Date)
	[object]$Ceased = $null
	[int]$Sequence
	[string]$Caption
	[double]$Elapsed
	[Alias('Something')] [single]$Slice

	static [string] LogFileName ($thing) {
		$folder = Join-Path $env:TEMP 'Ticker'
		if (!(Test-Path $folder)) {
			New-Item $folder -ItemType Directory | Out-Null
		}
		return Join-Path $folder $('{0}-Steps.txt' -f $($thing))
	}
	static [hashtable] Untick ([int64]$ticks) { return [Stepper]::Untick($ticks,3,$false) }
	static [hashtable] Untick ([int64]$Ticks,$sigFig,[switch]$Expanded) {
		if ($Expanded) {
			$sigFig = $null
		}

		$Units = @('Day','Hour','Minute','Second','Millisecond').ForEach{
			@{ Caption = $_
				TicksPer = [timespan]::('TicksPer{0}' -f ($_))
			}
		}
		$Units += @{ Caption = 'Nanosecond'; TicksPer = 100 }
		$Units += @{ Caption = 'Tick'; TicksPer = 1 }

		Write-Verbose ($units.ForEach{ [pscustomobject]$_ } | Out-String)
		Write-Verbose ('{0} Ticks' -f [long]$Ticks)
		$X = ''
		$tag = ''
		$result = @{}
		foreach ($unit in $units) {

			[float]$X = $Ticks / $unit.TicksPer
			Write-Verbose ('{0} {1}s' -f $X,$unit.Caption)
			if ($X -ge 1) {
				break
			}
		}
		$S = $(if ($X -ne ([int64]$X)) { 's' })
		$G = $(if ($sigFig) { ':g{0}' -f $sigFig })

		return @{
			Blurb = ("{0$G} {1}{2}" -f $x,$unit.Caption,($S))
			Unit = $unit.Caption
			Value = $X
			TicksPer = $unit.TicksPer
		}

	}

	static [void] Show ($Occasion) {
		$log = [Stepper]::FetchLog($Occasion)
		#region  Compute Unit of Measure

		$Measure = $log | Measure-Object Elapsed -Sum -Average -Minimum -Maximum

		$tickage = [Stepper]::Untick($Measure.Average)
		$W = $($tickage.Unit.Length)

		$Cols = @()
		$Cols += 'Occasion'
		$Cols += 'Caption'
		#$Z=$('{0:g3}' -f 1.2);if($Z.Length -lt 4){$Z.PadRight(4,'0')}else{$Z}
		<#$cols += @{ N = "$($tickage.Unit)"; E = {
				"{0,-$w}" -f $($($Z = $('{0:g3}' -f ($_.Elapsed / $tickage.TicksPer))
						if ($Z.Length -lt $W) {
							$Z.PadRight($w,'0')
						}
						else {
							$Z
						})) }
		}#>
		$cols += @{ N = "$($tickage.Unit)s"; E = {
				$([single](('{0:g3}' -f ($_.Elapsed / $tickage.TicksPer))).PadLeft($W)) }
		}
		$Cols += @{ N = 'Slice'; E = { [math]::Round($_.Slice) } }

		#endregion  Compute Unit of Measure
		Write-Verbose $($log | Format-Table $Cols | Out-String) -Verbose
		Write-Verbose $("Elapsed: $([string](new-timespan (get-date).AddTicks(-$Measure.Sum)))") -Verbose
		Write-Verbose $(([Stepper]::Untick($Measure.Sum)).Blurb) -Verbose
		<#
    $T=(New-TimeSpan (get-date).AddTicks(-$Measure.Sum)) 
    [Array]$D='',''
    if($T.Days)  {
    $D[0]='Days, '
    $D[1]='{0:d2}:' -f $T.Days    
    }
		Write-Verbose ("$($D[1]){0:d2}:{1:d2}:{2:d2}.{3:d3} ($($D[0])Hours, Minutes, Seconds)" -f $T.Hours,$T.Minutes,$T.Seconds,$T.Milliseconds) -Verbose
#>
		[Stepper]::CleanUp($Occasion)
	}
	static [Object[]] CloseItem ($syncSet) {
		foreach ($item in $syncSet) {
			$item.Ceased = (Get-Date)
			$item.Elapsed = ($item.Ceased.Ticks - $item.Intiated.Ticks) #/ [timespan]::TicksPersecond
		}
		return $syncSet
	}
	Stepper ([string]$Occasion) { $this.Stepper($Occasion,$null) }
	#Stepper ([string]$Occasion,$Caption) { $this.TrueStepper($Occasion,$Caption) }

	Stepper ([string]$Occasion,$Caption) {
		$this.Occasion = $Occasion
		[stepper]::CleanUp($Occasion)
		$logfile = [Stepper]::LogFileName($this.Occasion)
		$log = @()
		$prior = @()
		if (Test-Path $logfile) {
			$log += Import-Clixml $logfile
		}
		if ($log) { $prior = $log | Where-Object { [string]::IsNullOrEmpty($_.Ceased) } | sort Initiated }

		$syncSet = [stepper]::closeItem($prior)
		$this.Intiated = (Get-Date)
		$this.sequence = $log.count + 1
		if ($Caption) {
			$this.Caption = $Caption
		} else {
			$this.Caption = 'Step {0}' -f $this.sequence
		}
		$log += $this

		$log | Export-Clixml $logfile
		[Stepper]::Evaluate($Occasion)
	}
	static Evaluate ($Occasion) {
		[array]$log = [Stepper]::FetchLog($Occasion)
		$sv = ($log | Out-String).trim()
		$summary = ($log | Measure-Object -Sum Elapsed)
		foreach ($item in $log | Where-Object { $_.Ceased }) {
			$item.Slice = '{0:g3}' -f (($item.Elapsed / $summary.Sum) * 100)
		}
		if (($log | Out-String).trim() -ne $sv) {
			$log | Export-Clixml $([Stepper]::LogFileName($Occasion))
		}

	}
	static [object] FetchLog ($Occasion) {
		$logfile = [Stepper]::LogFileName($Occasion)
		$log = @()
		if (Test-Path $logfile) {
			$log += Import-Clixml $logfile
		}
		return $log
	}
	<#
			Evaluate ($log) {
			$Alpha = $log | Measure-Object -Sum Elapsed

			foreach ($item in $log | Where-Object { $_.Ceased }) {
			$item.Slice = '{0:g3}' -f (($item.Elapsed / $Alpha.Sum) * 100)
			}
			return $log
	}#>
	static Complete ($Occasion) {
		<#<!-- [Complete]
				Stops and closes the bar
		-->#>
		$log = [Stepper]::FetchLog($Occasion)

		$Bottom = $log | sort Squence | Select-Object -Last 1
		<#if ([string]::IsNullOrEmpty($Bottom.Ceased)) {
				$Bottom.Ceased = (Get-Date)
				$Bottom.Elapsed = ($Bottom.Ceased.Ticks - $Bottom.Intiated.Ticks) #/ [timespan]::TicksPersecond
		}#>
		$Bottom = [stepper]::closeItem($Bottom)
		$log | Export-Clixml $([Stepper]::LogFileName($Occasion))
		[Stepper]::Evaluate($Occasion)

	}
	static CleanUp ($Occasion) { [Stepper]::CleanUp($Occasion,60) }
	static CleanUp ($Occasion,$expiry) {
		<#
				$logfile = $([Stepper]::LogFileName($Occasion))
				if (Test-Path $logfile) {
				Remove-Item $logfile
				}
		#>
		$logfile = $([Stepper]::LogFileName($Occasion))
		$files = Get-ChildItem (Split-Path $logfile) |
		Where-Object { (New-TimeSpan $_.LastWriteTime).TotalMinutes -gt $expiry } |
		Where-Object { $_.FullName -ne $logfile }
		@($files).ForEach{ $_.Delete() }
	}
}
[flags()] enum RecapMethod{
	Properties = 1
	StepDetail = 2
	ISE_Only = 0x100
}
class Ticker{
	<#
			<!-- [Synopsis]
			QND Progress Bar
			-->

			<!-- [Description]
			Wrapper Class for Write-Progress to easily display a progress bar
			-->

	#>
	<# Properties

			<!-- [Activity]
			Name of the progress bar
			-->

			<!-- [ID]
			identifier for the progress bar
			-->

			<!-- [Max]
			is the Upper Limit; The count at which the Progress is Completed
			-->

			<!-- [Ocassion]
			Instance ID
			-->

			<!-- [ParentID]
			established hierarchical order of multiple progress bars
			-->

			<!-- [Recapitualtion]
			Display Details of Steps Processed 
			<li>Properties - Shows write-Progress Summary Properites
			<li>StepDetail - Displays Time each step took and Percentage of the whole
			-->

			<!-- [Segments]
			Number of Segments included in progess bar
			-->

			<!-- [Steps]
			Detials of Steps for Step Method
			-->
			<!-- [CountSteps]
			Counts Number of time the Step Method is called in Calling Script
			And sets the $This.Max to the corresponding number of calls
			-->
	#>
	#>
	[string]$Activity
	hidden [string]$Blurb
	hidden [int]$Counter = 1
	hidden [double]$Done
	hidden [int]$Incr
	hidden [int]$Mark
	[int]$Max = 0
	hidden [int]$OverHead = 0
	hidden [int]$NextUpdate = 0
	[int]$Segments = 150
	hidden [Diagnostics.Stopwatch]$StopWatch
	hidden [double]$Togo
	hidden [int]$Updates = 0
	hidden [bool]$Updated
	[int]$ID = 0
	[int]$ParentID = -1
	hidden [string]$Mode
	hidden [bool]$Completed = $false
	hidden [string]$spinchars = '\|/---'
	hidden [array]
	#Only hiding to make .Step method more identifiable
	$Steps = @()
	[FlashID]$Ocassion = [FlashID]::POP()
	[RecapMethod]$Recapitualtion = [RecapMethod]::ISE_Only
	hidden [bool]$Recap
	hidden [string]$ElapsedString

	hidden Setup ([hashtable]$Options)
	{

		if ($Options)
		{
			if ($Options.GetType().Name -eq 'Hashtable')
			{
				foreach ($key in $Options.Keys)
				{
					switch ($key) {
						{ $_ -in 'Activity','Segments','Max','ID','ParentID' }
						{ $this.$key = $Options.$_ }
					}
				}
			}
		}
		if (!$this.Activity)
		{# $this.Activity = 'Unknown Activity' 
    $this.Activity="$((Get-PSCallStack)[2].Location)"
    }
		if (!$this.Segments)
		{ $this.Segments = $this.Max }
		$this.SetIncr()
		$this.StopWatch = [Diagnostics.Stopwatch]::new()
		<#
				$x = ($this.Max) / 25
				$this.spinchars = "$(''.PadRight($x,'-'))$(''.PadRight($x,'\'))$(''.PadRight($x,'|'))$(''.PadRight($x,'/'))"
		#>
		$this.SetSpinCars()
		if ($this.StopWatch.ElapsedTicks -ne 0)
		{
			$this.StopWatch.Stop()
			$this.StopWatch.Reset()
		}
	}
	hidden SetSpinCars () {
		$x = ($this.Max) / 25
		$this.spinchars = "$(''.PadRight($x,'-'))$(''.PadRight($x,'\'))$(''.PadRight($x,'|'))$(''.PadRight($x,'/'))"
	}
	hidden SetIncr ()
	{
		if ($this.Max -ge $this.Segments)
		{ $this.Incr = [math]::Ceiling($this.Max / $this.Segments) }
		else
		{ $this.Incr = 1 }
	}
	hidden TrueTick ($Options)
	{
		$Status = $null
		$this.Mode = $null
		if ($Options)
		{
			if ($Options.GetType().Name -eq 'Hashtable')
			{
				foreach ($key in $Options.Keys)
				{
					switch ($key) {
						{
							$_ -in 'CurrentOperation','Mode'
						}
						{
							$this.$key = $Options.$_
						}

					}
				}
			}
		}
		if ($this.Mode -eq 'Spin')
		{
			if ($this.Max -lt 25) {
				Write-Error 'Max must be at least 25 in spin mode' -ErrorAction Stop
			}

		}
		if (!$this.StopWatch.IsRunning)
		{
			$this.StopWatch.Start()
		}
		$this.Updated = $false
		if ($this.counter -ge $this.NextUpdate)
		{
			[int]$this.mark = $this.StopWatch.ElapsedMilliseconds
			if ($this.Mode -eq 'Step') {
				$offset = -1
			} else {
				$offset = 0

			}
			if ($this.counter -le $this.Max)
			{
				<# Elimination the offset feature
						$this.done = (($this.counter + $offset) / $this.Max) * 100
				#>
				$this.done = ($this.counter / $this.Max) * 100
				$this.togo = (($this.StopWatch.ElapsedMilliseconds / $this.counter) * ($this.Max - $this.counter)) / 1000
			}
			else
			{
				if ($this.Mode -eq 'Spin')
				{
					$this.done = 0
					$this.togo = 100
					$this.counter = 1

				}
				else
				{

					$this.done = 100
					$this.togo = 0
					$this.counter = $this.Max
					$this.Incr = $this.Max

				}
			}
			$this.ElapsedString = 'Elapsed Time: {0:HH:mm:ss}' -f ([datetime]$this.StopWatch.ElapsedTicks)
			$paging = "$(if ($this.mode -eq 'Step'){'step '})$($this.counter) of $($this.Max)"
			$splat = @{
				ID = $this.ID
				ParentID = $this.ParentID
				Activity = $this.Activity
				PercentComplete = $this.done
				Status = $this.ElapsedString
				#CurrentOperation = $this.CurrentOperation
				#Completed = $this.Completed
				#SecondsRemaining = $this.togo

			}
			if ($this.Mode -eq 'Tick') {
				$splat.SecondsRemaining = $this.togo
			}
			if ($Options.Message)
			{
				$splat.CurrentOperation = "$(if($this.Mode -eq 'Step'){"($Paging) "})$($Options.Message)"
			}
			if ([string]::IsNullOrEmpty($splat.CurrentOperation)) {
				if ($this.Mode -ne 'Spin') {
					$splat.CurrentOperation = $paging

				}
			}
			if ($this.Mode -eq 'Spin') {
				$splat.Activity = '{1} {0}' -f $($this.spinchars.Substring(($this.counter % ($this.spinchars.Length)),1)),$this.Activity
			}
			Write-Progress @splat
			Start-Sleep -Milliseconds 1
			$this.NextUpdate = $this.counter + $this.Incr
			$this.Updates++
			[int]$this.Overhead = $this.Overhead + ($this.StopWatch.ElapsedMilliseconds - $this.mark)
			$this.Updated = $true
		}
		$this.counter++
	}
	[void] Tick ()
	{
		<#
				<!-- [Tick]
				Shows the bar and does all the work
				-->
		#>
		$this.TrueTick(@{ Mode = 'Tick' })
	}
	[void] Tick ($Message)
	{ $this.TrueTick(@{ Mode = 'Tick'; 'Message' = $Message }) }
	[void] Step () {
		#-- Increments the bar. You can also update the Activity with each step
		$this.TrueTick(@{ Mode = 'Step' })
	}
	[void] step ($Message) {
		<#
				<!-- [Step]
				Increments the bar. You can also update the Activity with each step
				-->
		#>
		$this.TrueTick(@{ Mode = 'Step'; 'Message' = $Message })
		$this.Steps += [Stepper]::new($this.Ocassion,$message)
	}
	[void] Spin ($Message) {
		<#
				<!-- [Spin]
				Used when then endpoint of the progress bar is unknown. Increments the bar
				-->
		#>
		if (!$this.Completed) {
			$this.Incr = 1
			$splatter = @{ Mode = 'Spin' }
			if (!([string]::IsNullOrEmpty($Message))) {
				#$splatter.Status = $message
				$splatter.'Message' = $Message
			}
			$this.TrueTick($splatter)
		}

	}
	[void] Spin () {
		$this.Spin($null)

	}
	Ticker ([string]$Activity,[int]$Max)
	{ $this.Setup(@{ Activity = $Activity; Max = $Max }) }
	Ticker ([string]$Activity,[int]$Max,[int]$ID)
	{ $this.Setup(@{ Activity = $Activity; Max = $Max; ID = $ID }) }
	Ticker ([string]$Activity,[int]$Max,[int]$ID,[int]$ParentID)
	{ $this.Setup(@{ Activity = $Activity; Max = $Max; ID = $ID; ParentID = $ParentID }) }
	Ticker ([string]$Activity,[int]$Max,[int]$ID,[int]$ParentID,[int]$Segments)
	{ $this.Setup(@{ Activity = $Activity; Max = $Max; ID = $ID; ParentID = $ParentID; Segments = $Segments }) }
	Ticker ([hashtable]$Options)
	{
		#-- $Options Passed as a Hash Table can set any known properties
		$this.Setup($Options)
	}
	Complete ([RecapMethod]$Method) { $this.Recapitualtion = ($this.Recapitualtion -bor $Method); $this.Complete() }
	Complete () {

		<#
				<!-- [Complete]
				Stops and closes the bar
				-->
		#>

		$this.StopWatch.Stop()
		$this.Completed = $true
		Write-Progress -Activity $this.Activity -Completed -Id $this.ID -PercentComplete 100
		if (!$this.Recapitualtion) {
			if ($this.Recap) {
				$this.Recapitualtion = [RecapMethod]::Properties -bor [RecapMethod]::StepDetail
			}

		}
		if (([RecapMethod]$this.Recapitualtion).HasFlag([RecapMethod]::ISE_Only)) {
			if ($global:host.Name -notmatch 'PowerShell ISE') {
				$this.Recapitualtion = 0
			}
		}

		if ($this.Recapitualtion) {
			if ($this.Recapitualtion.HasFlag([RecapMethod]::Properties)) {
				$props = ([ticker]::new('',1,1) | Get-Member -Force -MemberType Property).Name
				$Wide = ($props | Select-Object * | Measure-Object Length -Maximum).Maximum
				foreach ($prop in $props) {
					Write-Host $("{0,-$Wide} : {1}" -f $prop,$this. "$($prop)")
				}
			}
			if ($this.Recapitualtion.HasFlag([RecapMethod]::StepDetail)) {

				if ($this.Steps) {
					[Stepper]::Complete($this.Ocassion)
					#[stepper]::Evaluate($this.Ocassion)
					[Stepper]::Show($this.Ocassion)
					#[Stepper]::CleanUp($this.Ocassion)

				}
			}
		}
		Write-Progress -Activity $this.Activity -Completed -Id $this.ID # -PercentComplete 100

		[System.GC]::Collect()
		[GC]::Collect()
		[GC]::WaitForPendingFinalizers()
		Start-Sleep -Milliseconds 1

	}
	Restart ()
	{
		<#
				<!-- [Restart]
				Resets all Class Properties to Thier Initial Values
				-->
		#>
		$this.counter = 1
		$this.NextUpdate = 0
		$this.Updates = 0
		$this.togo = 100
		$this.done = 0
		$this.StopWatch.Stop()
		$this.StopWatch.Reset()
		$this.SetIncr()
		$this.mark = 0
	}
	static help ()
	{
		$helpFile = Join-Path $PSScriptRoot 'Ticker.html'
		if (Test-Path $helpFile) {
			Invoke-Item $helpFile
		} else {
			Write-Warning "Can't find $helpfile.  Oops.  8-|"
		}
	}
	CountSteps () {
		$callStack = (Get-PSCallStack)[1]
		$content = Get-Content $callStack.ScriptName
		$target = $callStack.Position.Text

		$searcher = '{0}.Step(' -f ($target.Substring(0,$target.IndexOf('.')))
		$this.Max = ($content -match [regex]::Escape($searcher)).count
	}
}
<#
		if (Get-Module 'C-TickerClass') {
		Remove-Module 'C-TickerClass'
		}
		$Ticker = [Ticker]::new('Alpha',25)
		$Spinner = [Ticker]::new('Spinner',25,1,0)
		$Stepper = [Ticker]::new('Stepper',$ticker.Max * 25,2,0)
		for ($i = 0; $i -lt 25; $i++) {
		$Ticker.Step("Step $i")
		for ($j = 0; $j -lt 25; $j++) {
		$Spinner.Spin($("Stepping $j"))
		$Stepper.Step()
		Start-Sleep -Milliseconds 5
		}
		}
#>
<#
if (Get-Module 'C-TickerClass') {
	Remove-Module 'C-TickerClass'
}

$myColors = [enum]::GetNames([ConsoleColor]) | Get-Random -Count ((Get-Random 10))
$Stepper = [Ticker]::new('Recap Enhancement',$myColors.count)
foreach ($color in $myColors) {
	$Stepper.Step($color)
	#Start-Sleep -Milliseconds (Get-Random 5)
}

$Stepper.Complete([RecapMethod]::StepDetail)
#>

