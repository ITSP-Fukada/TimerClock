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
$script:alarmTimeInput = $mainWindow.FindName("AlarmTimeInput")
$setAlarmButton = $mainWindow.FindName("SetAlarmButton")
$cancelAlarmButton = $mainWindow.FindName("CancelAlarmButton")
$remainingTimeDisplay = $mainWindow.FindName("RemainingTimeDisplay") # New assignment for the new TextBlock

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
$alarmCheckTimer.Interval = New-TimeSpan -Seconds 1
$alarmCheckTimer.Add_Tick({
    $currentTime = Get-Date # Get current time once for consistency

    if ($script:alarmTime -and $currentTime -ge $script:alarmTime) {
        $alarmCheckTimer.Stop()
        [System.Windows.MessageBox]::Show("設定した時間になりました！", "アラーム",
[System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        $statusText.Text = "アラーム完了"
        $script:alarmTime = $null # Reset alarm after it triggers
        $remainingTimeDisplay.Text = "" # Clear remaining time display
    }
    if ($alarmRadio.IsChecked -and $script:alarmTime) {
        $timeRemaining = $script:alarmTime.Subtract($currentTime)
        if ($timeRemaining.TotalSeconds -gt 0) {
            $remainingTimeDisplay.Text = "残り時間: {0:D2}:{1:D2}:{2:D2}" -f $timeRemaining.Hours, $timeRemaining.Minutes, $timeRemaining.Seconds
        } else {
            $remainingTimeDisplay.Text = "" # Clear if alarm time has passed but not yet triggered (e.g., missed window)
        }
    }
})

$setAlarmButton.Add_Click({
    try {
        $inputTime = [DateTime]::ParseExact($script:alarmTimeInput.Text, "HH:mm", $null)
        $script:alarmTime = $inputTime
        $statusText.Text = "アラーム設定: $($script:alarmTime.ToString('HH:mm'))"
        $alarmCheckTimer.Start()
    }
    catch {
        [System.Windows.MessageBox]::Show("無効な時刻フォーマットです。HH:mm形式で入力してください。", "エラー",
[System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        $statusText.Text = "アラーム設定エラー"
    }
})

$cancelAlarmButton.Add_Click({
    $alarmCheckTimer.Stop()
    $script:alarmTime = $null
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
        }
        else {
            $script:isWorkPhase = $true
            $script:pomodoroRemainingTime = $pomodoroWorkDuration
            $script:pomodoroState = "Stopped"
            $pomodoroStatusText.Text = "ポモドーロ: 準備完了"
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
        $startPomodoroButton.IsEnabled = $false
        $pausePomodoroButton.IsEnabled = $true
    }
})

$pausePomodoroButton.Add_Click({
    if ($script:pomodoroState -eq "Working" -or $script:pomodoroState -eq "Breaking") {
        $pomodoroTimer.Stop()
        $script:pomodoroState = "Paused"
        $pomodoroStatusText.Text = "一時停止中"
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
