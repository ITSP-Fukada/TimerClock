param()

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

# region Constants for Pomodoro
$pomodoroWorkDuration  = New-TimeSpan -Minutes 25
$pomodoroBreakDuration = New-TimeSpan -Minutes 5
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
$alarmTimeInput = $mainWindow.FindName("AlarmTimeInput")
$setAlarmButton = $mainWindow.FindName("SetAlarmButton")
$cancelAlarmButton = $mainWindow.FindName("CancelAlarmButton")

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
$alarmTime = $null
$alarmCheckTimer = New-Object System.Windows.Threading.DispatcherTimer
$alarmCheckTimer.Interval = New-TimeSpan -Seconds 1
$alarmCheckTimer.Add_Tick({
    if ($alarmTime) {
        Write-Host "Current Time: $((Get-Date).ToString("HH:mm:ss")) - Alarm Time: $($alarmTime.ToString("HH:mm"))"
    }
    if ($alarmTime -and (Get-Date -Format "HH:mm") -eq (Get-Date $alarmTime -Format "HH:mm")) {
        $alarmCheckTimer.Stop()
        [System.Windows.MessageBox]::Show("設定した時間になりました！", "アラーム",
[System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        $statusText.Text = "アラーム完了"
        $alarmTime = $null # Reset alarm after it triggers
    }
})

$setAlarmButton.Add_Click({
    try {
        $inputTime = [DateTime]::ParseExact($alarmTimeInput.Text, "HH:mm", $null)
        $alarmTime = $inputTime
        $statusText.Text = "アラーム設定: $($alarmTime.ToString('HH:mm'))"
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
    $alarmTime = $null
    $statusText.Text = "アラームキャンセル"
})
# endregion

# region Pomodoro Functionality
$pomodoroState = "Stopped" # "Stopped", "Working", "Breaking", "Paused"
$pomodoroRemainingTime = $pomodoroWorkDuration
$isWorkPhase = $true

$pomodoroTimer = New-Object System.Windows.Threading.DispatcherTimer
$pomodoroTimer.Interval = New-TimeSpan -Seconds 1
$pomodoroTimer.Add_Tick({
    $pomodoroRemainingTime = $pomodoroRemainingTime.Subtract([TimeSpan]::FromSeconds(1))

    if ($pomodoroRemainingTime.TotalSeconds -le 0) {
        $pomodoroTimer.Stop()
        [System.Windows.MessageBox]::Show("時間です！", "ポモドーロ", [System.Windows.MessageBoxButton]::OK,
[System.Windows.MessageBoxImage]::Information)

        if ($isWorkPhase) {
            $isWorkPhase = $false
            $pomodoroRemainingTime = $pomodoroBreakDuration
            $pomodoroState = "Breaking"
            $pomodoroStatusText.Text = "休憩中..."
        }
        else {
            $isWorkPhase = $true
            $pomodoroRemainingTime = $pomodoroWorkDuration
            $pomodoroState = "Stopped"
            $pomodoroStatusText.Text = "ポモドーロ: 準備完了"
            $startPomodoroButton.IsEnabled = $true
            $pausePomodoroButton.IsEnabled = $false
            $resetPomodoroButton.IsEnabled = $true
        }
        if ($pomodoroState -ne "Stopped") {
            $pomodoroTimer.Start()
        }
    }
    $pomodoroTimerDisplay.Text = "{0:D2}:{1:D2}" -f [int]$pomodoroRemainingTime.Minutes,
[int]$pomodoroRemainingTime.Seconds
})

$startPomodoroButton.Add_Click({
    if ($pomodoroState -eq "Stopped" -or $pomodoroState -eq "Paused") {
        $pomodoroTimer.Start()
        $pomodoroState = if ($isWorkPhase) { "Working" } else { "Breaking" }
        $pomodoroStatusText.Text = if ($isWorkPhase) { "作業中..." } else { "休憩中..." }
        $startPomodoroButton.IsEnabled = $false
        $pausePomodoroButton.IsEnabled = $true
    }
})

$pausePomodoroButton.Add_Click({
    if ($pomodoroState -eq "Working" -or $pomodoroState -eq "Breaking") {
        $pomodoroTimer.Stop()
        $pomodoroState = "Paused"
        $pomodoroStatusText.Text = "一時停止中"
        $startPomodoroButton.IsEnabled = $true
        $pausePomodoroButton.IsEnabled = $false
    }
})

$resetPomodoroButton.Add_Click({
    $pomodoroTimer.Stop()
    $pomodoroState = "Stopped"
    $isWorkPhase = $true
    $pomodoroRemainingTime = $pomodoroWorkDuration
    $pomodoroTimerDisplay.Text = "{0:D2}:{1:D2}" -f [int]$pomodoroRemainingTime.Minutes,
[int]$pomodoroRemainingTime.Seconds
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
    $pomodoroState = "Stopped"
    $isWorkPhase = $true
    $pomodoroRemainingTime = $pomodoroWorkDuration
    $pomodoroTimerDisplay.Text = "{0:D2}:{1:D2}" -f [int]$pomodoroRemainingTime.Minutes,
[int]$pomodoroRemainingTime.Seconds
    $pomodoroStatusText.Text = "ポモドーロ: 準備完了"
    $startPomodoroButton.IsEnabled = $true
    $pausePomodoroButton.IsEnabled = $false
})

$pomodoroRadio.Add_Checked({
    $statusText.Text = "ポモドーロ機能が選択されました"
    $alarmControls.Visibility = [System.Windows.Visibility]::Collapsed
    $pomodoroControls.Visibility = [System.Windows.Visibility]::Visible
    # Ensure Pomodoro display is correct when selected
    $pomodoroTimerDisplay.Text = "{0:D2}:{1:D2}" -f [int]$pomodoroRemainingTime.Minutes,
[int]$pomodoroRemainingTime.Seconds
    $pomodoroStatusText.Text = "ポモドーロ: 準備完了"
    $startPomodoroButton.IsEnabled = $true
    $pausePomodoroButton.IsEnabled = $false
    # Make sure to stop any running alarm timer when switching to pomodoro mode
    $alarmCheckTimer.Stop()
    $alarmTime = $null
})
# endregion

# Initial setup for Pomodoro buttons and display
$pomodoroTimerDisplay.Text = "{0:D2}:{1:D2}" -f [int]$pomodoroWorkDuration.Minutes,
[int]$pomodoroWorkDuration.Seconds
$startPomodoroButton.IsEnabled = $true
$pausePomodoroButton.IsEnabled = $false
$resetPomodoroButton.IsEnabled = $true

$mainWindow.ShowDialog() | Out-Null
