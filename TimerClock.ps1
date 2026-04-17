param()

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

# region Constants for Pomodoro
$pomodoroWorkDuration  = New-TimeSpan -Minutes 25
$pomodoroBreakDuration = New-TimeSpan -Minutes 5
# endregion

# region UI Colors
$clockDefaultColor = "Black"
$remainingTimeDefaultColor = "LightGray"
$activeTimerColor = "Red"
$breakTimeColor = "Orange"
# endregion

# region Load XAML
$xamlPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "TimerClock.xaml"
[xml]$xaml = (Get-Content $xamlPath | Out-String)

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$mainWindow = [System.Windows.Markup.XamlReader]::Load($reader)

# Assign controls to variables
$timeDisplay = $mainWindow.FindName("TimeDisplay")
$alwaysOnTopCheckbox = $mainWindow.FindName("AlwaysOnTopCheckbox")
$alarmRadio = $mainWindow.FindName("AlarmRadio")
$pomodoroRadio = $mainWindow.FindName("PomodoroRadio")
$statusText = $mainWindow.FindName("StatusText")

# New UI elements
$alarmControls = $mainWindow.FindName("AlarmControls")
$alarmHourInput = $mainWindow.FindName("AlarmHourInput")
$alarmMinuteInput = $mainWindow.FindName("AlarmMinuteInput")
$setAlarmButton = $mainWindow.FindName("SetAlarmButton")
$cancelAlarmButton = $mainWindow.FindName("CancelAlarmButton")
$quickPlus5 = $mainWindow.FindName("QuickPlus5")
$quickPlus10 = $mainWindow.FindName("QuickPlus10")
$quickPlus30 = $mainWindow.FindName("QuickPlus30")
$quickPlus60 = $mainWindow.FindName("QuickPlus60")
$remainingTimeDisplay = $mainWindow.FindName("RemainingTimeDisplay") # New assignment for the new TextBlock

# Populate Alarm ComboBoxes
0..23 | ForEach-Object { [void]$alarmHourInput.Items.Add($_.ToString("D2")) }
0..59 | ForEach-Object { [void]$alarmMinuteInput.Items.Add($_.ToString("D2")) }

# Set initial alarm time to current time
$now = Get-Date
$alarmHourInput.SelectedItem = $now.Hour.ToString("D2")
$alarmMinuteInput.SelectedItem = $now.Minute.ToString("D2")

# Set initial colors
$timeDisplay.Foreground = [System.Windows.Media.Brushes]::$clockDefaultColor
$remainingTimeDisplay.Foreground = [System.Windows.Media.Brushes]::$remainingTimeDefaultColor

$pomodoroControls = $mainWindow.FindName("PomodoroControls")
$pomodoroStatusText = $mainWindow.FindName("PomodoroStatusText")
$pomodoroTimerDisplay = $mainWindow.FindName("PomodoroTimerDisplay")
$startPomodoroButton = $mainWindow.FindName("StartPomodoroButton")
$pausePomodoroButton = $mainWindow.FindName("PausePomodoroButton")
$resetPomodoroButton = $mainWindow.FindName("ResetPomodoroButton")

# endregion

# region Clock Update
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = New-TimeSpan -Seconds 1
$timer.Add_Tick({
    $timeDisplay.Text = (Get-Date).ToString("HH:mm:ss")
})
$timer.Start()
# endregion

# region Always On Top Functionality
$alwaysOnTopCheckbox.Add_Checked({ $mainWindow.Topmost = $true })
$alwaysOnTopCheckbox.Add_Unchecked({ $mainWindow.Topmost = $false })
# endregion

# region Alarm Functionality
$script:alarmTime = $null
$alarmCheckTimer = New-Object System.Windows.Threading.DispatcherTimer
$alarmCheckTimer.Interval = [TimeSpan]::FromMilliseconds(100) # Check more frequently for precision
$alarmCheckTimer.Add_Tick({
    $currentTime = Get-Date

    if ($script:alarmTime) {
        $timeRemaining = $script:alarmTime.Subtract($currentTime)
        
        # Trigger when time is reached or passed
        if ($timeRemaining.TotalSeconds -le 0) {
            $alarmCheckTimer.Stop()
            $remainingTimeDisplay.Foreground = [System.Windows.Media.Brushes]::$remainingTimeDefaultColor
            $remainingTimeDisplay.Text = "残り時間: 00:00:00"
            
            [System.Windows.MessageBox]::Show("設定した時間になりました！", "アラーム",
[System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            
            $statusText.Text = "アラーム完了"
            $script:alarmTime = $null
            $remainingTimeDisplay.Text = ""
        }
        elseif ($alarmRadio.IsChecked) {
            # Use Ceiling so it shows 00:00:01 until it hits exactly 0
            $totalSecs = [Math]::Ceiling($timeRemaining.TotalSeconds)
            $h = [Math]::Floor($totalSecs / 3600)
            $m = [Math]::Floor(($totalSecs % 3600) / 60)
            $s = $totalSecs % 60
            $remainingTimeDisplay.Text = "残り時間: {0:D2}:{1:D2}:{2:D2}" -f [int]$h, [int]$m, [int]$s
        }
    }
})

$setAlarmButton.Add_Click({
    try {
        $hour = [int]$alarmHourInput.SelectedItem
        $minute = [int]$alarmMinuteInput.SelectedItem
        
        $now = Get-Date
        $inputTime = Get-Date -Hour $hour -Minute $minute -Second 0
        
        # If the input time is in the past today, assume it's for tomorrow
        if ($inputTime -lt $now) {
            $inputTime = $inputTime.AddDays(1)
        }
        
        $script:alarmTime = $inputTime
        $statusText.Text = "アラーム設定: $($script:alarmTime.ToString('MM/dd HH:mm'))"
        $remainingTimeDisplay.Foreground = [System.Windows.Media.Brushes]::$activeTimerColor
        $alarmCheckTimer.Start()
    }
    catch {
        [System.Windows.MessageBox]::Show("設定エラーが発生しました。", "エラー",
[System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        $statusText.Text = "アラーム設定エラー"
    }
})

# Quick Add logic
$updateComboBoxes = {
    param($time)
    $alarmHourInput.SelectedItem = $time.Hour.ToString("D2")
    $alarmMinuteInput.SelectedItem = $time.Minute.ToString("D2")
}

$quickPlus5.Add_Click({
    $newTime = (Get-Date).AddMinutes(5)
    &$updateComboBoxes $newTime
})
$quickPlus10.Add_Click({
    $newTime = (Get-Date).AddMinutes(10)
    &$updateComboBoxes $newTime
})
$quickPlus30.Add_Click({
    $newTime = (Get-Date).AddMinutes(30)
    &$updateComboBoxes $newTime
})
$quickPlus60.Add_Click({
    $newTime = (Get-Date).AddHours(1)
    &$updateComboBoxes $newTime
})

$cancelAlarmButton.Add_Click({
    $alarmCheckTimer.Stop()
    $script:alarmTime = $null
    $remainingTimeDisplay.Foreground = [System.Windows.Media.Brushes]::$remainingTimeDefaultColor
    $statusText.Text = "アラームキャンセル"
})
# endregion

# region Pomodoro Functionality
$script:pomodoroState = "Stopped" # "Stopped", "Working", "Breaking", "Paused"
$script:pomodoroRemainingTime = $pomodoroWorkDuration
$script:isWorkPhase = $true

$pomodoroTimer = New-Object System.Windows.Threading.DispatcherTimer
$pomodoroTimer.Interval = New-TimeSpan -Seconds 1
$pomodoroTimer.Add_Tick({
    $script:pomodoroRemainingTime = $script:pomodoroRemainingTime.Subtract([TimeSpan]::FromSeconds(1))

    if ($script:pomodoroRemainingTime.TotalSeconds -le 0) {
        $pomodoroTimer.Stop()
        [System.Windows.MessageBox]::Show("時間です！", "ポモドーロ", [System.Windows.MessageBoxButton]::OK,
    [System.Windows.MessageBoxImage]::Information)

        if ($script:isWorkPhase) {
            $script:isWorkPhase = $false
            $script:pomodoroRemainingTime = $pomodoroBreakDuration
            $script:pomodoroState = "Breaking"
            $pomodoroStatusText.Text = "休憩中..."
            $pomodoroTimerDisplay.Foreground = [System.Windows.Media.Brushes]::$breakTimeColor
            $remainingTimeDisplay.Foreground = [System.Windows.Media.Brushes]::$breakTimeColor
        }
        else {
            $script:isWorkPhase = $true
            $script:pomodoroRemainingTime = $pomodoroWorkDuration
            $script:pomodoroState = "Stopped"
            $pomodoroStatusText.Text = "ポモドーロ: 準備完了"
            $pomodoroTimerDisplay.Foreground = [System.Windows.Media.Brushes]::$clockDefaultColor
            $remainingTimeDisplay.Foreground = [System.Windows.Media.Brushes]::$remainingTimeDefaultColor
            $startPomodoroButton.IsEnabled = $true
            $pausePomodoroButton.IsEnabled = $false
            $resetPomodoroButton.IsEnabled = $true
            $remainingTimeDisplay.Text = "" # Clear display
        }
        if ($script:pomodoroState -ne "Stopped") {
            $pomodoroTimer.Start()
        }
    }
    if ($pomodoroRadio.IsChecked) {
        $remainingTimeDisplay.Text = "残り時間: {0:D2}:{1:D2}" -f [int]$script:pomodoroRemainingTime.Minutes, [int]$script:pomodoroRemainingTime.Seconds
    }
    $pomodoroTimerDisplay.Text = "{0:D2}:{1:D2}" -f [int]$script:pomodoroRemainingTime.Minutes,
    [int]$script:pomodoroRemainingTime.Seconds
})

$startPomodoroButton.Add_Click({
    if ($script:pomodoroState -eq "Stopped" -or $script:pomodoroState -eq "Paused") {
        $pomodoroTimer.Start()
        $script:pomodoroState = if ($script:isWorkPhase) { "Working" } else { "Breaking" }
        $pomodoroStatusText.Text = if ($script:isWorkPhase) { "作業中..." } else { "休憩中..." }
        
        $color = if ($script:isWorkPhase) { $activeTimerColor } else { $breakTimeColor }
        $pomodoroTimerDisplay.Foreground = [System.Windows.Media.Brushes]::$color
        $remainingTimeDisplay.Foreground = [System.Windows.Media.Brushes]::$color
        
        $startPomodoroButton.IsEnabled = $false
        $pausePomodoroButton.IsEnabled = $true
    }
})

$pausePomodoroButton.Add_Click({
    if ($script:pomodoroState -eq "Working" -or $script:pomodoroState -eq "Breaking") {
        $pomodoroTimer.Stop()
        $script:pomodoroState = "Paused"
        $pomodoroStatusText.Text = "一時停止中"
        
        $pomodoroTimerDisplay.Foreground = [System.Windows.Media.Brushes]::$clockDefaultColor
        $remainingTimeDisplay.Foreground = [System.Windows.Media.Brushes]::$remainingTimeDefaultColor
        
        $startPomodoroButton.IsEnabled = $true
        $pausePomodoroButton.IsEnabled = $false
    }
})

$resetPomodoroButton.Add_Click({
    $pomodoroTimer.Stop()
    $script:pomodoroState = "Stopped"
    $script:isWorkPhase = $true
    $script:pomodoroRemainingTime = $pomodoroWorkDuration
    $pomodoroTimerDisplay.Text = "{0:D2}:{1:D2}" -f [int]$script:pomodoroRemainingTime.Minutes,
[int]$script:pomodoroRemainingTime.Seconds
    $pomodoroStatusText.Text = "ポモドーロ: 準備完了"
    
    $pomodoroTimerDisplay.Foreground = [System.Windows.Media.Brushes]::$clockDefaultColor
    $remainingTimeDisplay.Foreground = [System.Windows.Media.Brushes]::$remainingTimeDefaultColor
    
    $startPomodoroButton.IsEnabled = $true
    $pausePomodoroButton.IsEnabled = $false
})
# endregion

# region Event Handlers for Mode Selection
$alarmRadio.Add_Checked({
    $statusText.Text = "アラーム機能が選択されました"
    $alarmControls.Visibility = [System.Windows.Visibility]::Visible
    $pomodoroControls.Visibility = [System.Windows.Visibility]::Collapsed
    # Make sure to stop any running pomodoro timer when switching to alarm mode
    $pomodoroTimer.Stop()
    $script:pomodoroState = "Stopped"
    $script:isWorkPhase = $true
    $script:pomodoroRemainingTime = $pomodoroWorkDuration
    $pomodoroTimerDisplay.Text = "{0:D2}:{1:D2}" -f [int]$script:pomodoroRemainingTime.Minutes,
[int]$script:pomodoroRemainingTime.Seconds
    $pomodoroStatusText.Text = "ポモドーロ: 準備完了"
    $startPomodoroButton.IsEnabled = $true
    $pausePomodoroButton.IsEnabled = $false
    $remainingTimeDisplay.Text = "" # Clear remaining time when switching to alarm mode, will be populated by $alarmCheckTimer
})

$pomodoroRadio.Add_Checked({
    $statusText.Text = "ポモドーロ機能が選択されました"
    $alarmControls.Visibility = [System.Windows.Visibility]::Collapsed
    $pomodoroControls.Visibility = [System.Windows.Visibility]::Visible
    # Ensure Pomodoro display is correct when selected
    $pomodoroTimerDisplay.Text = "{0:D2}:{1:D2}" -f [int]$script:pomodoroRemainingTime.Minutes,
[int]$script:pomodoroRemainingTime.Seconds
    $pomodoroStatusText.Text = "ポモドーロ: 準備完了"
    $startPomodoroButton.IsEnabled = $true
    $pausePomodoroButton.IsEnabled = $false
    # Make sure to stop any running alarm timer when switching to pomodoro mode
    $alarmCheckTimer.Stop()
    $script:alarmTime = $null
    $remainingTimeDisplay.Text = "残り時間: {0:D2}:{1:D2}" -f [int]$script:pomodoroRemainingTime.Minutes, [int]$script:pomodoroRemainingTime.Seconds # Show initial pomodoro remaining time
})
# endregion

# Initial setup for Pomodoro buttons and display
$pomodoroTimerDisplay.Text = "{0:D2}:{1:D2}" -f [int]$pomodoroWorkDuration.Minutes,
[int]$pomodoroWorkDuration.Seconds
$startPomodoroButton.IsEnabled = $true
$pausePomodoroButton.IsEnabled = $false
$resetPomodoroButton.IsEnabled = $true

$mainWindow.ShowDialog() | Out-Null
