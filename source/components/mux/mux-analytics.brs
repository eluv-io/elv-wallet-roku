sub init()
    m.MUX_SDK_VERSION = "2.0.2"
    m.top.id = "mux"
    m.top.functionName = "runBeaconLoop"
end sub

function runBeaconLoop()
    m.messagePort = _createPort()
    appInfo = _createAppInfo()

    m.MAX_BEACON_SIZE = 300 'controls size of a single beacon (in events)
    m.MAX_QUEUE_LENGTH = 3600 '1 minute to clean a full queue
    m.BASE_TIME_BETWEEN_BEACONS = 10000
    m.HEARTBEAT_INTERVAL = 10000
    m.POSITION_TIMER_INTERVAL = 250 '250
    m.SEEK_THRESHOLD = 1250 'ms jump in position before a seek is considered'
    m.HTTP_RETRIES = 10 'number of times to reattempt http call'

    m.pollTimer = CreateObject("roSGNode", "Timer")
    m.pollTimer.id = "pollTimer"
    m.pollTimer.repeat = true
    m.pollTimer.duration = m.POSITION_TIMER_INTERVAL / 1000

    ' m.heartbeatTimer = m.top.findNode("heartbeatTimer")
    m.heartbeatTimer = CreateObject("roSGNode", "Timer")
    m.heartbeatTimer.id = "heartbeatTimer"
    m.heartbeatTimer.repeat = true
    m.heartbeatTimer.duration = m.HEARTBEAT_INTERVAL / 1000

    m.beaconTimer = CreateObject("roSGNode", "Timer")
    m.beaconTimer.id = "beaconTimer"
    m.beaconTimer.repeat = true
    m.beaconTimer.duration = m.BASE_TIME_BETWEEN_BEACONS / 1000
    m.beaconTimer.control = "start"

    m.httpPort = _createPort()

    useRandomMuxViewerId = false
    if m.top.randomMuxViewerId <> invalid
        useRandomMuxViewerId = m.top.randomMuxViewerId
    end if

    m.mxa = muxAnalytics()
    m.mxa.MUX_SDK_VERSION = m.MUX_SDK_VERSION

    print "[mux-analytics] running task loop"

    systemConfig = {
        MAX_BEACON_SIZE: m.MAX_BEACON_SIZE,
        MAX_QUEUE_LENGTH: m.MAX_QUEUE_LENGTH,
        HTTP_RETRIES: m.HTTP_RETRIES,
        BASE_TIME_BETWEEN_BEACONS: m.BASE_TIME_BETWEEN_BEACONS,
        HEARTBEAT_INTERVAL: m.HEARTBEAT_INTERVAL,
        POSITION_TIMER_INTERVAL: m.POSITION_TIMER_INTERVAL,
        SEEK_THRESHOLD: m.SEEK_THRESHOLD,
        USE_RANDOM_MUX_VIEWER_ID: useRandomMuxViewerId
    }
    m.mxa.init(appInfo, systemConfig, m.top.config, m.heartbeatTimer, m.pollTimer, m.httpPort)

    m.top.ObserveField("rafEvent", m.messagePort)

    if m.top.video = invalid
        m.top.ObserveField("video", m.messagePort)
    else
        m.mxa.videoAddedHandler(m.top.video)
        m.top.video.ObserveField("state", m.messagePort)
        m.top.video.ObserveField("content", m.messagePort)
        m.top.video.ObserveField("control", m.messagePort)
        m.top.video.ObserveField("licenseStatus", m.messagePort)
        m.top.video.ObserveField("contentIndex", m.messagePort)
        m.top.video.ObserveField("downloadedSegment", m.messagePort)
        m.top.video.ObserveField("streamingSegment", m.messagePort)
        if m.top.video.enableDecoderStats <> invalid
            m.top.video.enableDecoderStats = true
            m.top.video.ObserveField("decoderStats", m.messagePort)
        end if
    end if

    if m.top.view <> invalid and m.top.view <> ""
        m.mxa.videoViewChangeHandler(m.top.view)
    end if
    m.top.ObserveField("view", m.messagePort)

    if m.top.config <> invalid
        m.mxa.configChangeHandler(m.top.config)
    end if
    m.top.ObserveField("config", m.messagePort)

    if m.top.useRenderStitchedStream <> invalid
        m.mxa.useRenderStitchedStreamHandler(m.top.useRenderStitchedStream)
    end if
    m.top.ObserveField("useRenderStitchedStream", m.messagePort)

    if m.top.useSSAI <> invalid
        m.mxa.useSSAIHandler(m.top.useSSAI)
    end if
    m.top.ObserveField("useSSAI", m.messagePort)

    if m.top.disableAutomaticErrorTracking <> invalid
        m.mxa.disableAutomaticErrorTrackingHandler(m.top.disableAutomaticErrorTracking)
    end if
    m.top.ObserveField("disableAutomaticErrorTracking", m.messagePort)

    if m.top.error <> invalid
        m.mxa.videoErrorHandler(m.top.error)
    end if
    m.top.ObserveField("error", m.messagePort)

    m.pollTimer.ObserveField("fire", m.messagePort)
    m.beaconTimer.ObserveField("fire", m.messagePort)
    m.heartbeatTimer.ObserveField("fire", m.messagePort)

    ' Track exit on a separate port per Roku's guidance
    m.exitPort = _createPort()
    m.top.ObserveField("exit", m.exitPort)

    running = true
    while running
        exitMsg = wait(10, m.exitPort)
        httpMsg = wait(10, m.httpPort)
        msg = wait(30, m.messagePort)
        if exitMsg <> invalid
            data = exitMsg.getData()
            if data = true
                running = false
            end if
        end if
        if httpMsg <> invalid
            m.mxa._handleHttpEvent(httpMsg)
        end if
        if msg <> invalid
            msgType = type(msg)
            if msgType = "roSGNodeEvent"
                field = msg.getField()
                if field = "video"
                    if m.top.video = invalid
                        m.top.UnobserveField("video")
                        data = msg.getData()
                        m.mxa.videoAddedHandler(data)
                        m.top.video.ObserveField("state", m.messagePort)
                        m.top.video.ObserveField("content", m.messagePort)
                        m.top.video.ObserveField("control", m.messagePort)
                        m.top.video.ObserveField("licenseStatus", m.messagePort)
                        m.top.video.ObserveField("contentIndex", m.messagePort)
                        m.top.video.ObserveField("downloadedSegment", m.messagePort)
                        m.top.video.ObserveField("streamingSegment", m.messagePort)
                        if m.top.video.enableDecoderStats <> invalid
                            m.top.video.enableDecoderStats = true
                            m.top.video.ObserveField("decoderStats", m.messagePort)
                        end if
                    end if
                else if field = "config"
                    m.mxa.configChangeHandler(msg.getData())
                else if field = "useRenderStitchedStream"
                    m.mxa.useRenderStitchedStreamHandler(msg.getData())
                else if field = "useSSAI"
                    m.mxa.useSSAIHandler(msg.getData())
                else if field = "disableAutomaticErrorTracking"
                    m.mxa.disableAutomaticErrorTrackingHandler(msg.getData())
                else if field = "error"
                    m.mxa.videoErrorHandler(msg.getData())
                else if field = "control"
                    m.mxa.videoControlChangeHandler(msg.getData())
                else if field = "contentIndex"
                    m.mxa.videoContentIndexChangeHandler(msg.getData())
                else if field = "streamingSegment"
                    m.mxa.videoStreamingSegmentChangeHandler(msg.getData())
                else if field = "downloadedSegment"
                    m.mxa.videoDownloadedSegmentChangeHandler(msg.getData())
                else if field = "decoderStats"
                    m.mxa.videoDecoderStatsChangeHandler(msg.getData())
                else if field = "licenseStatus"
                    m.mxa.drmLicenseStatusChangeHandler(msg.getData())
                else if field = "view"
                    m.mxa.videoViewChangeHandler(msg.getData())
                else if field = "state"
                    msgData = msg.getData()
                    if msgData <> invalid and type(msgData) = "roString"
                        m.mxa.videoStateChangeHandler(msgData)
                    end if
                else if field = "rafEvent"
                    m.mxa.rafEventHandler(msg)
                else if field = "fire"
                    node = msg.getNode()
                    if node = "pollTimer"
                        m.mxa.pollingIntervalHandler(msg)
                    else if node = "beaconTimer"
                        m.mxa.beaconIntervalHandler(msg)
                    else if node = "heartbeatTimer"
                        m.mxa.heartbeatIntervalHandler(msg)
                    end if
                end if
            end if
        end if

        ' Check to see if we need to retry
        m.mxa._retryBeacon()
    end while
    m.beaconTimer.control = "stop"
    m.heartbeatTimer.control = "stop"
    m.pollTimer.control = "stop"

    m.beaconTimer.UnobserveField("fire")
    m.heartbeatTimer.UnobserveField("fire")
    m.pollTimer.UnobserveField("fire")

    m.top.UnobserveField("video")
    m.top.UnobserveField("config")
    m.top.UnobserveField("control")
    m.top.UnobserveField("view")
    m.top.UnobserveField("useRenderStitchedStream")
    m.top.UnobserveField("useSSAI")
    m.top.UnobserveField("disableAutomaticErrorTracking")

    if m.top.exitType = "soft"
        while not m.mxa.isQueueEmpty()
            m.mxa.LIGHT_THE_BEACONS()
        end while
    end if

    'video player doesn't reset the playlist field. Has to reset it default to prevent crash on next video play
    if m.top.video <> invalid and m.top.video.contentIsPlaylist = true
        m.top.video.content = invalid
        m.top.video.contentIsPlaylist = false
    end if

    m.top.exit = false

    print "[mux-analytics] end running task loop"
    return true
end function

function _createConnection(port as object) as object
    connection = CreateObject("roUrlTransfer")
    connection.SetPort(port)
    connection.SetCertificatesFile("common:/certs/ca-bundle.crt")
    connection.AddHeader("Content-Type", "application/json")
    connection.AddHeader("Accept", "*/*")
    connection.AddHeader("Expect", "")
    connection.AddHeader("Connection", "keep-alive")
    connection.AddHeader("Accept-Encoding", "gzip, deflate, br")
    connection.EnableEncodings(true)
    return connection
end function

function _createDeviceInfo() as object
    return CreateObject("roDeviceInfo")
end function

function _createPort() as object
    return CreateObject("roMessagePort")
end function

function _createByteArray() as object
    return CreateObject("roByteArray")
end function

function _createAppInfo() as object
    return CreateObject("roAppInfo")
end function

function _createRegistry() as object
    return CreateObject("roRegistrySection", "mux")
end function

' Firmware Version Number
' Return 8.01, 9.01, etc if FW 9.1 or less
' Otherwise return 9.2, 9.3, 10.1, etc
function _firmwareVersionNumber(deviceInfo as object)
    if FindMemberFunction(deviceInfo, "GetOSVersion") = invalid
        version = deviceInfo.GetVersion().Mid(2, 4)
    else
        osVersion = deviceInfo.GetOSVersion()
        version = osVersion["major"] + "." + osVersion["minor"]
    end if
    return version
end function

function _getConnectionType(deviceInfo as object)
    connectionType = deviceInfo.GetConnectionType()
    if connectionType = "WiFiConnection"
        return "wifi"
    end if
    if connectionType = "WiredConnection"
        return "ethernet"
    end if

    return "none"
end function

function muxAnalytics() as object
    prototype = {}

    prototype.MUX_SDK_VERSION = ""
    prototype.MUX_SDK_NAME = "roku-mux"
    prototype.PLAYER_SOFTWARE_NAME = "RokuSG"
    prototype.MUX_API_VERSION = "2.1" ' 2.1 because of GUIDs for player instance IDs
    prototype.PLAYER_IS_FULLSCREEN = "true"

    prototype.init = sub(appInfo as object, systemConfig as object, customerConfig as object, hbt as object, pp as object, hp as object)
        m.httpPort = hp
        m.connection = _createConnection(m.httpPort)
        m.httpRetries = 5
        m.httpTimeout = 1500
        m.heartbeatTimer = hbt
        m.pollTimer = pp
        m.loggingPrefix = "[mux-analytics] "
        m.DEFAULT_DRY_RUN = false
        m.DEFAULT_DEBUG_EVENTS = "none"
        m.DEFAULT_DEBUG_BEACONS = "none" 'full','partial','none'
        m.DEFAULT_BEACON_URL = "https://img.litix.io"

        manifestDryRun = appInfo.GetValue("mux_dry_run")
        m.manifestBaseUrl = appInfo.GetValue("mux_base_url")
        manifestDebugEvents = appInfo.GetValue("mux_debug_events")
        manifestDebugBeacons = appInfo.GetValue("mux_debug_beacons")

        m.debugEvents = m.DEFAULT_DEBUG_EVENTS
        if manifestDebugEvents <> ""
            if manifestDebugEvents = "full" or manifestDebugEvents = "partial" or manifestDebugEvents = "none"
                m.debugEvents = manifestDebugEvents
            end if
        end if

        m.debugBeacons = m.DEFAULT_DEBUG_BEACONS
        if manifestDebugBeacons <> ""
            if manifestDebugBeacons = "full" or manifestDebugBeacons = "partial" or manifestDebugBeacons = "none"
                m.debugBeacons = manifestDebugBeacons
            end if
        end if

        m.dryRun = m.DEFAULT_DRY_RUN
        if manifestDryRun <> ""
            if manifestDryRun = "true"
                m.dryRun = true
            else
                m.dryRun = false
            end if
        end if

        m.beaconUrl = m.DEFAULT_BEACON_URL

        if m.manifestBaseUrl <> ""
            m.beaconUrl = m.manifestBaseUrl
        end if

        m.MAX_BEACON_SIZE = systemConfig.MAX_BEACON_SIZE
        m.MAX_QUEUE_LENGTH = systemConfig.MAX_QUEUE_LENGTH
        m.HTTP_RETRIES = systemConfig.HTTP_RETRIES
        m.BASE_TIME_BETWEEN_BEACONS = systemConfig.BASE_TIME_BETWEEN_BEACONS
        m.HEARTBEAT_INTERVAL = systemConfig.HEARTBEAT_INTERVAL
        m.POSITION_TIMER_INTERVAL = systemConfig.POSITION_TIMER_INTERVAL
        m.SEEK_THRESHOLD = systemConfig.SEEK_THRESHOLD

        m._configProperties = customerConfig

        m._eventQueue = []
        m._seekThreshold = m.SEEK_THRESHOLD / 1000

        ' variables
        m._beaconCount = 0
        m._inView = false
        m._playerSequence = 0
        m._startTimestamp = invalid
        m._viewStartTimestamp = invalid
        m._playerViewCount = invalid
        m._viewSequence = invalid
        m._viewId = invalid
        m._playerPlayheadTime = invalid
        m._viewTimeToFirstFrame = invalid
        m._playerTimeToFirstFrame = invalid
        m._contentPlaybackTime = invalid
        m._viewWatchTime = invalid
        m._viewRebufferCount = invalid
        m._viewRebufferDuration = invalid
        m._viewRebufferFrequency! = invalid
        m._viewRebufferPercentage = invalid
        m._viewSeekCount = invalid
        m._viewSeekStartTimeStamp = invalid
        m._viewSeekDuration = invalid
        m._viewAdPlayedCount = invalid
        m._viewPrerollPlayedCount = invalid
        m._videoSourceFormat = invalid
        m._videoSourceDuration = invalid
        m._viewPrerollPlayedCount = invalid

        m._lastSourceWidth = invalid
        m._lastSourceHeight = invalid
        m._lastPlayheadPosition = invalid
        m._lastVideoSegmentBitrate = invalid
        m._viewMaxUpscalePercentage = invalid
        m._viewMaxDownscalePercentage = invalid
        m._viewTotalUpscaling = invalid
        m._viewTotalDownscaling = invalid
        m._viewTotalContentPlaybackTime = invalid
        m._totalBytes = invalid
        m._totalLoadTime = invalid
        m._segmentRequestCount = invalid
        m._segmentRequestFailedCount = invalid
        m._viewMinRequestThroughput = invalid
        m._viewAverageRequestThroughput = invalid
        m._viewRequestCount = invalid

        ' Calculate player width and height
        deviceInfo = m._getDeviceInfo()
        videoMode = deviceInfo.GetVideoMode()
        m._lastPlayerWidth = Val(m._getVideoPlaybackMetric(videoMode, "width"))
        m._lastPlayerHeight = Val(m._getVideoPlaybackMetric(videoMode, "height"))

        ' flags
        m._Flag_lastVideoState = "none"
        m._Flag_isPaused = false
        m._Flag_atLeastOnePlayEventForContent = false
        m._Flag_RebufferingStarted = false
        m._Flag_isSeeking = false
        m._Flag_lastReportedPosition = 0
        m._Flag_FailedAdsErrorSet = false
        m._Flag_useSSAI = false
        m._Flag_automaticErrorTracking = true

        ' Flags specifically for when renderStitchedStream is used
        m._Flag_useRenderStitchedStream = false
        m._Flag_rssInAdBreak = false
        m._Flag_rssAdEnded = false
        m._Flag_rssContentPlayingAfterAds = false

        ' Flag for a beacon currently being retried
        m._Flag_beaconRequestInProgress = false

        ' Flag for whether or not to use a random mux viewer ID
        m._Flag_useRandomMuxViewerId = systemConfig.USE_RANDOM_MUX_VIEWER_ID

        ' kick off analytics
        date = m._getDateTime()
        m._startTimestamp = 0# + date.AsSeconds() * 1000.0# + date.GetMilliseconds()
        m._playerViewCount = 0
        m._sessionProperties = m._getSessionProperties()
        m._addEventToQueue(m._createEvent("playerready"))
    end sub

    prototype.beaconIntervalHandler = sub(beaconIntervalEvent)
        data = beaconIntervalEvent.getData()
        m.LIGHT_THE_BEACONS()
    end sub

    prototype.heartbeatIntervalHandler = sub(heartbeatIntervalEvent)
        data = heartbeatIntervalEvent.getData()
        if m._Flag_isPaused <> true
            m._addEventToQueue(m._createEvent("hb"))
        end if
    end sub

    prototype.videoAddedHandler = sub(video as object)
        m._videoProperties = m._getVideoProperties(video)
        if video.contentIsPlaylist = true
            m._videoContentProperties = m._getVideoContentProperties(video.content.getChild(video.contentIndex))
        else
            m._videoContentProperties = m._getVideoContentProperties(video.content)
        end if
        m.video = video

        if video <> invalid
            maximumPossiblePositionChange = ((video.notificationInterval * 1000) + m.POSITION_TIMER_INTERVAL) / 1000
            if m._seekThreshold < maximumPossiblePositionChange
                m._seekThreshold = maximumPossiblePositionChange
            end if
        end if
    end sub

    prototype.videoStateChangeHandler = sub(videoState as string)
        m.video_state = videoState
        previouslyLastReportedPosition = m._Flag_lastReportedPosition
        m._playerPlayheadTime = m.video.position
        m._Flag_lastReportedPosition = m._playerPlayheadTime

        ' Need to actually infer seek all the way out here
        if m._Flag_isSeeking <> true
            ' If we've gone backwards at all or forwards by more than the threshold
            if (m._playerPlayheadTime < previouslyLastReportedPosition) or (m._playerPlayheadTime > (previouslyLastReportedPosition + m._seekThreshold))
                if videoState = "buffering"
                    m._addEventToQueue(m._createEvent("pause"))
                end if
                m._addEventToQueue(m._createEvent("seeking"))
                date = m._getDateTime()
                m._viewSeekStartTimeStamp = 0# + date.AsSeconds() * 1000.0# + date.GetMilliseconds()
                if m._viewSeekCount <> invalid
                    m._viewSeekCount++
                end if
                m._Flag_isSeeking = true
            end if
        end if

        m._Flag_isPaused = (videoState = "paused")

        if videoState = "buffering"
            if m._Flag_atLeastOnePlayEventForContent = true
                m._addEventToQueue(m._createEvent("rebufferstart"))
                m._Flag_RebufferingStarted = true
                if m._viewRebufferCount <> invalid
                    m._viewRebufferCount++
                    if m._viewWatchTime <> invalid and m._viewWatchTime > 0
                        m._viewRebufferFrequency! = m._viewRebufferCount / m._viewWatchTime
                    end if
                end if
            end if
        else if videoState = "paused"
            m._addEventToQueue(m._createEvent("pause"))
        else if videoState = "playing"
            m._videoProperties = m._getVideoProperties(m.video)

            if m._Flag_lastVideoState = "buffering"
                if m._Flag_RebufferingStarted = true
                    m._addEventToQueue(m._createEvent("rebufferend"))
                    m._Flag_RebufferingStarted = false
                end if
            end if

            if m._Flag_isSeeking = true
                date = m._getDateTime()
                now = 0# + date.AsSeconds() * 1000.0# + date.GetMilliseconds()
                seekStartTs = 0#
                if m._viewSeekStartTimeStamp <> invalid
                    seekStartTs = m._viewSeekStartTimeStamp
                end if
                if m._viewSeekDuration <> invalid
                    m._viewSeekDuration = m._viewSeekDuration + (now - seekStartTs)
                end if
                m._addEventToQueue(m._createEvent("seeked"))
                m._Flag_isSeeking = false

                ' We will emit the play from paused states further down if needed
                if m._Flag_lastVideoState <> "paused"
                    m._addEventToQueue(m._createEvent("play"))
                end if
            end if

            if m._Flag_atLeastOnePlayEventForContent = false
                if m._viewTimeToFirstFrame = invalid
                    if m._viewStartTimestamp <> invalid and m._viewStartTimestamp <> 0
                        date = m._getDateTime()
                        now = 0# + date.AsSeconds() * 1000.0# + date.GetMilliseconds()
                        m._viewTimeToFirstFrame = now - m._viewStartTimestamp
                    end if
                end if
            end if
            if m._Flag_lastVideoState = "paused"
                m._addEventToQueue(m._createEvent("play"))
            end if
            m._addEventToQueue(m._createEvent("playing"))
            m._Flag_isSeeking = false
            m._Flag_atLeastOnePlayEventForContent = true
        else if videoState = "stopped"
        else if videoState = "finished"
            ' Only send ended event if it played to completion
            completedStreamInfo = m.video.completedStreamInfo
            if completedStreamInfo <> invalid
                if completedStreamInfo.isFullResult
                    m._addEventToQueue(m._createEvent("ended"))
                end if
            end if
        else if videoState = "error"
            ' Bail out if we aren't supposed to track automatic errors
            if not m._Flag_automaticErrorTracking then return

            errorCode = ""
            errorMessage = ""
            errorContext = ""
            if m.video <> invalid
                if m.video.errorCode <> invalid
                    errorCode = m.video.errorCode
                end if
                if m.video.errorMsg <> invalid
                    errorMessage = m.video.errorMsg
                end if
                if m.video.errorStr <> invalid
                    errorContext = m.video.errorStr
                end if
            end if
            m._addEventToQueue(m._createEvent("error", { player_error_code: errorCode, player_error_message: errorMessage, player_error_context: errorContext }))
        end if
        m._Flag_lastVideoState = videoState
    end sub

    prototype.drmLicenseStatusChangeHandler = sub(licenseStatus as object)
        if licenseStatus <> invalid
            if licenseStatus.keysystem <> invalid
                m.drmType = licenseStatus.keysystem
            end if
        end if
    end sub

    prototype.videoViewChangeHandler = sub(view as string)
        if view = "end"
            m._endView(true)
        else if view = "start"
            m._startView(true)
        end if
    end sub

    prototype._triggerPlayEvent = sub()
        if m.video <> invalid
            if m.video.content <> invalid
                if m.video.contentIsPlaylist
                    m._videoContentProperties = m._getVideoContentProperties(m.video.content.getChild(m.video.contentIndex))
                else
                    m._videoContentProperties = m._getVideoContentProperties(m.video.content)
                end if
            end if
            m._videoProperties = m._getVideoProperties(m.video)
        end if
        m._addEventToQueue(m._createEvent("play"))
    end sub

    prototype.videoControlChangeHandler = sub(control as string)
        if control = "play"
            m._startView()
            m._triggerPlayEvent()
        else if control = "stop"
            m._endView()
        end if
    end sub

    prototype.videoContentChangeHandler = sub(videoContent as object)
        if m._clientOperatedStartAndEnd <> true
            m._endView()
            m._startView()
        end if
    end sub

    prototype.videoContentIndexChangeHandler = sub(contentIndex as integer)
        if contentIndex > 0
            m._addEventToQueue(m._createEvent("ended"))
            m._endView(true)
            m._startView(true)
            m._triggerPlayEvent()
            if m._Flag_atLeastOnePlayEventForContent = false
                if m._viewTimeToFirstFrame = invalid
                    if m._viewStartTimestamp <> invalid and m._viewStartTimestamp <> 0
                        date = m._getDateTime()
                        now = 0# + date.AsSeconds() * 1000.0# + date.GetMilliseconds()
                        m._viewTimeToFirstFrame = now - m._viewStartTimestamp
                    end if
                end if
            end if
            m._addEventToQueue(m._createEvent("playing"))
        end if
    end sub

    prototype.videoStreamingSegmentChangeHandler = sub(videoSegment as object)
        if videoSegment <> invalid
            ' For now, we only listen for video or media segments for all of our calculations
            if videoSegment.segType = 0 or videoSegment.segType = 2
                if m._lastPlayerWidth <> invalid and m._lastPlayerHeight <> invalid and m._lastPlayheadPosition <> invalid and m._lastSourceWidth <> invalid and m._lastSourceHeight <> invalid and videoSegment.segStartTime <> invalid
                    player_playhead_time = Int(videoSegment.segStartTime * 1000)
                    if m._lastPlayerWidth >= 0 and m._lastPlayerHeight >= 0 and m._lastPlayheadPosition >= 0 and player_playhead_time >= 0 and m._lastSourceWidth > 0 and m._lastSourceHeight > 0
                        timeDiff = player_playhead_time - m._lastPlayheadPosition
                        scale = m._min(m._lastPlayerWidth / m._lastSourceWidth, m._lastPlayerHeight / m._lastSourceHeight)
                        upscale = m._max(0, scale - 1)
                        downscale = m._max(0, 1 - scale)
                        m._viewMaxUpscalePercentage = m._max(m._viewMaxUpscalePercentage, upscale)
                        m._viewMaxDownscalePercentage = m._max(m._viewMaxDownscalePercentage, downscale)
                        m._viewTotalContentPlaybackTime = m._safeAdd(m._viewTotalContentPlaybackTime, timeDiff)
                        m._viewTotalUpscaling = m._safeAdd(m._viewTotalUpscaling, upscale * timeDiff)
                        m._viewTotalDownscaling = m._safeAdd(m._viewTotalDownscaling, downscale * timeDiff)
                    end if
                end if
                if videoSegment.width <> invalid and videoSegment.height <> invalid and videoSegment.segBitrateBps <> invalid
                    if m._lastSourceWidth <> invalid and m._lastSourceWidth <> videoSegment.width or m._lastSourceHeight <> invalid and m._lastSourceHeight <> videoSegment.height or m._lastVideoSegmentBitrate <> invalid and m._lastVideoSegmentBitrate <> videoSegment.segBitrateBps
                        details = { video_source_width: videoSegment.width, video_source_height: videoSegment.height, video_source_bitrate: videoSegment.segBitrateBps }
                        m._addEventToQueue(m._createEvent("renditionchange", details))
                    end if
                end if
                m._lastSourceWidth = videoSegment.width
                m._lastSourceHeight = videoSegment.height
                m._lastVideoSegmentBitrate = videoSegment.segBitrateBps
                m._lastPlayheadPosition = Int(videoSegment.segStartTime * 1000)
            end if
        end if
    end sub

    prototype.videoDownloadedSegmentChangeHandler = sub(videoSegment as object)
        if m._segmentRequestCount = invalid then m._segmentRequestCount = 0
        m._segmentRequestCount++
        if videoSegment <> invalid
            props = {}
            if videoSegment.segType <> invalid
                if videoSegment.segType = 0
                    props.request_type = "media"
                else if videoSegment.segType = 1
                    props.request_type = "audio"
                else if videoSegment.segType = 2
                    props.request_type = "video"
                else if videoSegment.segType = 3
                    props.request_type = "captions"
                end if
            end if
            if videoSegment.segDuration <> invalid
                props.request_media_duration = videoSegment.segDuration
            end if
            if videoSegment.downloadDuration <> invalid
                date = m._getDateTime()
                now = 0# + date.AsSeconds() * 1000.0# + date.GetMilliseconds()
                props.request_response_end = FormatJson(now)
                resultMilliseconds = now - videoSegment.downloadDuration
                props.request_start = FormatJson(resultMilliseconds)
            end if
            if videoSegment.segUrl <> invalid
                props.request_hostname = m._getHostname(videoSegment.segUrl)
            end if
            if videoSegment.status <> invalid
                if videoSegment.status = 0
                    if videoSegment.segSize <> invalid
                        props.request_bytes_loaded = videoSegment.segSize
                    end if
                    if videoSegment.width <> invalid
                        props.request_video_width = videoSegment.width
                    end if
                    if videoSegment.height <> invalid
                        props.request_video_height = videoSegment.height
                    end if
                    if videoSegment.downloadDuration <> invalid and videoSegment.downloadDuration > 0 and videoSegment.segSize <> invalid and videoSegment.segSize > 0
                        loadTime = videoSegment.downloadDuration / 1000
                        throughput = (videoSegment.segSize * 8) / loadTime ' in bits / sec
                        m._totalBytes = m._safeAdd(m._totalBytes, videoSegment.segSize)
                        m._totalLoadTime = m._safeAdd(m._totalLoadTime, loadTime)
                        if m._viewMinRequestThroughput = invalid
                            m._viewMinRequestThroughput = throughput
                        else
                            m._viewMinRequestThroughput = m._min(m._viewMinRequestThroughput, throughput)
                        end if
                        m._viewAverageRequestThroughput = (m._totalBytes * 8) / m._totalLoadTime
                        m._viewRequestCount = m._segmentRequestCount
                    end if
                    m._addEventToQueue(m._createEvent("requestcompleted", props))
                else
                    if m._segmentRequestFailedCount = invalid then m._segmentRequestFailedCount = 0
                    m._segmentRequestFailedCount++
                    props.view_request_failed_count = m._segmentRequestFailedCount
                    m._addEventToQueue(m._createEvent("requestfailed", props))
                end if
            end if
        end if
    end sub

    prototype.videoDecoderStatsChangeHandler = sub(decoderStats as object)
        if decoderStats <> invalid
            if decoderStats.frameDropCount <> invalid
                m.droppedFrames = decoderStats.frameDropCount
            end if
        end if
    end sub

    prototype.configChangeHandler = sub(config as object)
        m._configProperties = config
        if config.beaconCollectionDomain <> invalid and config.beaconCollectionDomain <> ""
            m.beaconUrl = "https://" + config.beaconCollectionDomain
        else if config.env_key <> invalid and config.env_key <> ""
            m.beaconUrl = m._createBeaconUrl(config.env_key)
        else if config.property_key <> invalid and config.property_key <> ""
            m.beaconUrl = m._createBeaconUrl(config.property_key)
        end if
    end sub

    prototype.useRenderStitchedStreamHandler = sub(useRenderStitchedStream as boolean)
        if useRenderStitchedStream <> invalid
            m._Flag_useRenderStitchedStream = useRenderStitchedStream
        end if
    end sub

    prototype.useSSAIHandler = sub(useSSAI as boolean)
        if useSSAI <> invalid
            m._Flag_useSSAI = useSSAI
        end if
    end sub

    prototype.disableAutomaticErrorTrackingHandler = sub(disableAutomaticErrorTracking as boolean)
        if disableAutomaticErrorTracking <> invalid
            m._Flag_automaticErrorTracking = (not disableAutomaticErrorTracking)
        end if
    end sub

    prototype.videoErrorHandler = sub(error as object)
        errorCode = "0"
        errorMessage = "Unknown"
        errorContext = "No additional information"
        errorSeverity = "fatal"
        isBusinessException = false
        if error <> invalid
            if error.errorCode <> invalid
                errorCode = error.errorCode
            end if
            if error.errorMsg <> invalid
                errorMessage = error.errorMsg
            end if
            if error.errorMessage <> invalid
                errorMessage = error.errorMessage
            end if
            if error.errorContext <> invalid
                errorContext = error.errorContext
            end if
            if error.errorSeverity <> invalid
                if error.errorSeverity = "warning"
                    errorSeverity = "warning"
                end if
            end if
            if error.isBusinessException <> invalid
                isBusinessException = (error.isBusinessException = "true" or error.isBusinessException)
            end if
        end if
        m._addEventToQueue(m._createEvent("error", { player_error_code: errorCode, player_error_message: errorMessage, player_error_context: errorContext, player_error_severity: errorSeverity, player_error_business_exception: isBusinessException }))
    end sub

    prototype.rafEventHandler = sub(rafEvent)
        data = rafEvent.getData()
        eventType = data.eventType
        obj = data.obj
        ctx = data.ctx

        ' Only pull the pieces of data we care about
        ' Previous instructions passed the full adIface in, which has a circular reference in some cases
        adMetadata = {}
        if obj <> invalid
            if obj.adurl <> invalid
                adMetadata.adTagUrl = obj.adurl
            end if
        end if

        m._advertProperties = {}

        ' Special case to handle if `renderStitchedStream` is used or not
        if m._Flag_useRenderStitchedStream = true
            m._renderStitchedStreamRafEventHandler(eventType, ctx, adMetadata)
        else
            m._rafEventHandler(eventType, ctx, adMetadata)
        end if
    end sub

    prototype._rafEventhandler = sub(eventType, ctx, adMetadata)
        m._Flag_isPaused = (eventType = "Pause")
        if eventType = "PodStart"
            m._advertProperties = m._getAdvertProperties(adMetadata)
            m._addEventToQueue(m._createEvent("adbreakstart"))
            ' In the case that this is SSAI, we need to signal an adplay and adplaying event
            if m._Flag_useSSAI = true
                m._addEventToQueue(m._createEvent("adplay"))
                m._addEventToQueue(m._createEvent("adplaying"))
            end if
        else if eventType = "PodComplete"
            m._addEventToQueue(m._createEvent("adbreakend"))
            m._Flag_FailedAdsErrorSet = false
            ' In the case that this is SSAI, we need to signal a play and playing event
            if m._Flag_useSSAI = true
                m._Flag_isPaused = false
                m._triggerPlayEvent()
                m._addEventToQueue(m._createEvent("playing"))
            end if
        else if eventType = "Impression"
            m._addEventToQueue(m._createEvent("adimpression"))
        else if eventType = "Pause"
            m._addEventToQueue(m._createEvent("adpause"))
        else if eventType = "Start"
            if m._viewTimeToFirstFrame = invalid
                if m._viewStartTimestamp <> invalid and m._viewStartTimestamp <> 0
                    date = m._getDateTime()
                    now = 0# + date.AsSeconds() * 1000.0# + date.GetMilliseconds()
                    m._viewTimeToFirstFrame = now - m._viewStartTimestamp
                end if
            end if
            ' mark us as having another ad being played
            if m._viewAdPlayedCount <> invalid
                m._viewAdPlayedCount++
            end if
            if m._viewPrerollPlayedCount <> invalid
                ' CHECK FOR PREROLL
                m._viewPrerollPlayedCount++
            end if
            m._advertProperties = m._getAdvertProperties(ctx)
            m._addEventToQueue(m._createEvent("adplay"))
            m._addEventToQueue(m._createEvent("adplaying"))
        else if eventType = "Resume"
            m._advertProperties = m._getAdvertProperties(ctx)
            m._addEventToQueue(m._createEvent("adplay"))
            m._addEventToQueue(m._createEvent("adplaying"))
        else if eventType = "Complete"
            m._addEventToQueue(m._createEvent("adended"))
        else if eventType = "NoAdsError"
            if m._Flag_FailedAdsErrorSet <> true
                ' For now, aderror events do not support codes and messages, but leaving
                ' this here for now for context in the future
                ' errorCode = ""
                ' errorMessage = ""
                ' if ctx <> Invalid
                '   if ctx.errcode <> Invalid
                '     errorCode = ctx.errcode
                '   end if
                '   if ctx.errmsg <> Invalid
                '     errorMessage = ctx.errmsg
                '   end if
                ' end if
                m._addEventToQueue(m._createEvent("aderror"))
                m._Flag_FailedAdsErrorSet = true
            end if
        else if eventType = "FirstQuartile"
            m._addEventToQueue(m._createEvent("adfirstquartile"))
        else if eventType = "Midpoint"
            m._addEventToQueue(m._createEvent("admidpoint"))
        else if eventType = "ThirdQuartile"
            m._addEventToQueue(m._createEvent("adthirdquartile"))
        else if eventType = "Skip"
            m._addEventToQueue(m._createEvent("adskipped"))
            m._addEventToQueue(m._createEvent("adended"))
        end if
    end sub

    prototype._renderStitchedStreamRafEventHandler = sub(eventType, ctx, adMetadata)
        if eventType = "AdStateChange"
            state = ctx.state
            m._advertProperties = m._getAdvertProperties(adMetadata)
            if state = "buffering"
                ' the buffering state is the first event we get in a new ad pod, so start
                ' our ad break here if we're not already in one
                if not m._Flag_rssInAdBreak
                    m._Flag_rssInAdBreak = true
                    m._addEventToQueue(m._createEvent("adbreakstart"))
                end if

                ' and always trigger adplay
                m._Flag_isPaused = false
                m._addEventToQueue(m._createEvent("adplay"))
            else if state = "playing"
                ' in the playing state, if we either resuming, we need adplay first
                if m._Flag_isPaused
                    m._Flag_isPaused = false
                    m._addEventToQueue(m._createEvent("adplay"))
                end if
                ' and always emit adplaying
                m._addEventToQueue(m._createEvent("adplaying"))
            else if state = "paused"
                m._Flag_isPaused = true
                m._addEventToQueue(m._createEvent("adpause"))
            end if
        else if eventType = "PodStart"
            ' Need to handle PodStart for non-pre-rolls
            if not m._Flag_rssInAdBreak
                m._Flag_rssInAdBreak = true
                if not m._Flag_isPaused
                    m._Flag_isPaused = true
                    m._addEventToQueue(m._createEvent("pause"))
                end if
                m._addEventToQueue(m._createEvent("adbreakstart"))
            end if
        else if eventType = "Complete"
            ' Complete signals an ad has finished playback
            m._Flag_rssAdEnded = true
            m._addEventToQueue(m._createEvent("adended"))
        else if eventType = "Impression"
            ' When an additional ad is played within an ad pod, we do not get
            ' the AdStateChange events or anything other than the Impression
            ' event to know that a new ad was played
            if m._Flag_rssAdEnded
                m._Flag_rssAdEnded = false
                m._addEventToQueue(m._createEvent("adplay"))
                m._addEventToQueue(m._createEvent("adplaying"))
            end if
        else if eventType = "PodComplete"
            m._Flag_rssInAdBreak = false
            m._Flag_isPaused = true
            m._addEventToQueue(m._createEvent("adbreakend"))
        else if eventType = "ContentPosition"
            ' we have a special case here to track the start of content after an ad break
            if not m._Flag_rssInAdBreak
                if m._Flag_isPaused
                    m._Flag_isPaused = false
                    m._triggerPlayEvent()
                    m._addEventToQueue(m._createEvent("playing"))
                end if
            end if
        else if eventType = "ContentStateChange"
            ' We really only care about this if we're _not_ in an ad break
            if not m._Flag_rssInAdBreak
                state = ctx.state
                if state = "buffering"
                    ' if m._Flag_isPaused
                    m._Flag_isPaused = false
                    m._triggerPlayEvent()
                    ' end if
                else if state = "playing"
                    ' We get the playing event after buffering on initial startup, but
                    ' also again on unpausing (without the buffering event), so we need
                    ' to send play if we're currently paused
                    if m._Flag_isPaused
                        m._Flag_isPaused = false
                        m._triggerPlayEvent()
                    end if
                    m._addEventToQueue(m._createEvent("playing"))
                else if state = "paused"
                    m._Flag_isPaused = true
                    m._addEventToQueue(m._createEvent("pause"))
                end if
            end if
        end if
    end sub

    prototype.pollingIntervalHandler = sub(pollingIntervalEvent)
        if m.video = invalid then return
        if m._Flag_isPaused = true then return

        m._playerPlayheadTime = m.video.position

        m._setBufferingMetrics()
        m._updateContentPlaybackTime()

        m._updateTotalWatchTime()
        m._updateLastReportedPositionFlag()
    end sub

    ' ' //////////////////////////////////////////////////////////////
    ' ' INTERNAL METHODS
    ' ' //////////////////////////////////////////////////////////////

    prototype._updateLastReportedPositionFlag = sub()
        if m._playerPlayheadTime = m._Flag_lastReportedPosition then return
        m._Flag_lastReportedPosition = m._playerPlayheadTime
    end sub

    prototype._updateContentPlaybackTime = sub()
        if m._playerPlayheadTime <= m._Flag_lastReportedPosition then return
        if m.video_state <> "playing" then return
        if m._contentPlaybackTime = invalid then return

        m._contentPlaybackTime = m._contentPlaybackTime + ((m._playerPlayheadTime - m._Flag_lastReportedPosition) * 1000)
    end sub

    prototype._updateTotalWatchTime = sub()
        if m.video_state = "paused" then return
        if m._viewWatchTime = invalid then return
        if m._viewStartTimestamp = invalid then return
        if m._viewTimeToFirstFrame = invalid then return
        if m._viewRebufferDuration = invalid then return
        if m._contentPlaybackTime = invalid then return

        m._viewWatchTime = m._viewTimeToFirstFrame + m._viewRebufferDuration + m._contentPlaybackTime
    end sub

    prototype._setBufferingMetrics = sub()
        if m.video_state <> "buffering" then return
        if m._Flag_atLeastOnePlayEventForContent <> true then return
        if m._viewRebufferDuration = invalid then return

        m._viewRebufferDuration = m._viewRebufferDuration + (m.pollTimer.duration * 1000)
        if m._viewWatchTime <> invalid and m._viewWatchTime > 0
            m._viewRebufferPercentage = m._viewRebufferDuration / m._viewWatchTime
        end if
    end sub

    prototype._addEventToQueue = sub(_event as object)
        m._logEvent(_event)
        ' If the heartbeat is running restart it.
        if m.heartbeatTimer.control = "start"
            m.heartbeatTimer.control = "stop"
            m.heartbeatTimer.control = "start"
        end if

        ' Only queue up the event if we have not reached
        ' the max queue size
        if m._eventQueue.count() <= m.MAX_QUEUE_LENGTH
            m._eventQueue.push(_event)
        end if
    end sub

    prototype.isQueueEmpty = function() as boolean
        return m._eventQueue.count() = 0
    end function

    prototype.LIGHT_THE_BEACONS = sub()
        ' If a request is already in progress, do nothing
        if m._Flag_beaconRequestInProgress then return

        queueSize = m._eventQueue.count()
        if queueSize = 0 then return

        if queueSize >= m.MAX_BEACON_SIZE
            beacon = []
            for i = 0 to m.MAX_BEACON_SIZE - 1 step 1
                beacon.push(m._eventQueue.shift())
            end for
        else
            beacon = []
            beacon.Append(m._eventQueue)
            m._eventQueue.Clear()
        end if
        m._sendBeacon(beacon)
    end sub

    prototype._sendBeacon = sub(beacon as object)
        m._beaconCount++
        if m.dryRun = true
            m._logBeacon(beacon, "DRY-BEACON")
        else
            if beacon.count() > 0
                m._logBeacon(beacon, "BEACON")
                m._minifiedBeacon = []
                for each b in beacon
                    m._minifiedBeacon.push(m._minify(b))
                end for
                m._retryCountdown = m.HTTP_RETRIES
                m._Flag_beaconRequestInProgress = true
                m._makeRequest()
            end if
        end if
    end sub

    prototype._makeRequest = sub()
        m._beaconRetryDelay = invalid
        m._beaconAttemptTimespan = invalid
        m.connection.AsyncCancel()
        m.connection.SetUrl(m.beaconUrl)
        m.requestId = m.connection.GetIdentity()
        requestBody = {}
        requestBody.events = m._minifiedBeacon
        fBody = FormatJson(requestBody)
        m.connection.AsyncPostFromString(fBody)
    end sub

    prototype._handleHttpEvent = sub(event as object)
        if not m._Flag_beaconRequestInProgress
            print "[mux-analytics] HTTP port event received when no request in progress"
            return
        end if

        if type(event) <> "roUrlEvent"
            print "[mux-analytics] Unknown HTTP port event"
            return
        end if

        ' Successful exit if a 2xx is returned
        statusCode = event.GetResponseCode()
        if statusCode >= 200 and statusCode < 300
            m._Flag_beaconRequestInProgress = false
            return
        end if

        ' Otherwise clean it up and set our delay and timer if we're not done
        if m._retryCountdown <= 0
            print "[mux-analytics] Retries exceeded for beacon, giving up"
            m._Flag_beaconRequestInProgress = false
            return
        end if

        base = m._min(m.HEARTBEAT_INTERVAL, 2 ^ (m.HTTP_RETRIES - m._retryCountdown) * 1000)
        m._beaconRetryDelay = Fix(base / 2 + Rnd(0) * base / 2)
        m._beaconAttemptTimespan = CreateObject("roTimespan")
        m._retryCountdown = m._retryCountdown - 1
    end sub

    prototype._retryBeacon = sub()
        ' If we have a retry, do it when ready
        if m._beaconRetryDelay = invalid or m._beaconAttemptTimespan = invalid then return

        if m._beaconAttemptTimespan.TotalMilliseconds() >= m._beaconRetryDelay
            m._makeRequest()
        end if
    end sub

    prototype._startView = sub(setByClient = false as boolean)
        if setByClient = true
            m._clientOperatedStartAndEnd = true
        end if
        if m._clientOperatedStartAndEnd = true and setByClient = false then return
        if m._inView = false
            m.heartbeatTimer.control = "start"
            m.pollTimer.control = "start"
            m._viewSequence = 0
            if m._playerViewCount <> invalid
                m._playerViewCount++
            end if
            m._viewId = m._generateGUID()
            m._viewWatchTime = 0
            m._contentPlaybackTime = 0
            m._viewRebufferCount = 0
            m._viewRebufferDuration = 0
            m._viewSeekCount = 0
            m._viewSeekDuration = 0#
            m._viewAdPlayedCount = 0
            m._viewPrerollPlayedCount = 0

            m._lastSourceWidth = 0
            m._lastSourceHeight = 0
            m._totalBytes = 0
            m._totalLoadTime = 0
            m._segmentRequestCount = 0
            m._segmentRequestFailedCount = 0

            m._Flag_lastReportedPosition = 0
            m._Flag_atLeastOnePlayEventForContent = false
            m._Flag_isSeeking = false
            date = m._getDateTime()
            m._viewStartTimestamp = 0# + date.AsSeconds() * 1000.0# + date.GetMilliseconds()

            if m.video <> invalid
                if m.video.content <> invalid
                    if m.video.contentIsPlaylist
                        m._videoContentProperties = m._getVideoContentProperties(m.video.content.getChild(m.video.contentIndex))
                    else
                        m._videoContentProperties = m._getVideoContentProperties(m.video.content)
                    end if
                end if
                m._videoProperties = m._getVideoProperties(m.video)
            end if

            m._addEventToQueue(m._createEvent("viewstart"))

            m._inView = true
        end if
    end sub

    prototype._endView = sub(setByClient = false as boolean)
        if m._clientOperatedStartAndEnd = true and setByClient = false then return
        if m._clientOperatedStartAndEnd = false and setByClient = true then return
        if m._inView = true
            m.heartbeatTimer.control = "stop"
            m.pollTimer.control = "stop"
            m._addEventToQueue(m._createEvent("viewend"))
            m._inView = false
            m._viewId = invalid
            m._viewStartTimestamp = invalid
            m._viewSequence = invalid
            m._playerPlayheadTime = invalid
            m._viewTimeToFirstFrame = invalid
            m._playerTimeToFirstFrame = invalid
            m._contentPlaybackTime = invalid
            m._viewWatchTime = invalid
            m._viewRebufferCount = invalid
            m._viewRebufferDuration = invalid
            m._viewRebufferFrequency! = invalid
            m._viewRebufferPercentage = invalid
            m._viewSeekCount = invalid
            m._viewSeekDuration = invalid
            m._viewAdPlayedCount = invalid
            m._viewPrerollPlayedCount = invalid
            m._videoSourceFormat = invalid
            m._videoSourceDuration = invalid
            m.drmType = invalid
            m.droppedFrames = invalid

            m._lastSourceWidth = invalid
            m._lastSourceHeight = invalid
            m._lastPlayheadPosition = invalid
            m._lastVideoSegmentBitrate = invalid
            m._viewMaxUpscalePercentage = invalid
            m._viewMaxDownscalePercentage = invalid
            m._viewTotalUpscaling = invalid
            m._viewTotalDownscaling = invalid
            m._viewTotalContentPlaybackTime = invalid
            m._totalBytes = invalid
            m._totalLoadTime = invalid
            m._segmentRequestCount = invalid
            m._viewMinRequestThroughput = invalid
            m._viewAverageRequestThroughput = invalid
            m._viewRequestCount = invalid
            m._segmentRequestFailedCount = invalid
        end if
    end sub

    prototype._createEvent = function(eventType as string, eventProperties = {} as object) as object
        newEvent = {}

        if m._playerSequence <> invalid
            m._playerSequence++
        end if

        if m._viewSequence <> invalid
            m._viewSequence++
        end if

        ' session properties are set once per player session
        if m._sessionProperties <> invalid
            newEvent.Append(m._sessionProperties)
        end if

        ' video content properties are checked once per view
        if m._videoContentProperties <> invalid
            newEvent.Append(m._videoContentProperties)
        end if

        'actual video values overwrite video content values such as duration
        if m._videoProperties <> invalid
            newEvent.Append(m._videoProperties)
        end if

        'advert properties are checked during ad events
        if m._advertProperties <> invalid
            newEvent.Append(m._advertProperties)
        end if

        'dynamic properties are checked during every event
        dynamicProperties = m._getDynamicProperties()
        newEvent.Append(dynamicProperties)
        newEvent.Append(eventProperties)

        'customer can overwrite ALL properties should they wish'
        if m._configProperties <> invalid
            newEvent.Append(m._configProperties)
        end if

        if newEvent.property_key = invalid or newEvent.property_key = ""
            if m._playerSequence <> invalid and m._playerSequence < 2
                print "[mux-analytics] warning property_key not set."
            end if
        end if

        date = m._getDateTime()
        newEvent.viewer_time = FormatJson(0# + date.AsSeconds() * 1000.0# + date.GetMilliseconds())

        newEvent.event = eventType
        return newEvent
    end function

    ' called once per application session'
    prototype._getSessionProperties = function() as object
        props = {}
        deviceInfo = m._getDeviceInfo()
        appInfo = m._getAppInfo()
        firmwareVersion = _firmwareVersionNumber(deviceInfo)

        ' HARDCODED
        props.player_sequence_number = 1
        props.player_software_name = m.PLAYER_SOFTWARE_NAME
        props.player_software_version = firmwareVersion
        props.viewer_application_name = appInfo.GetTitle() ' let them override
        props.viewer_application_version = appInfo.GetVersion()
        props.viewer_device_name = deviceInfo.GetModelDisplayName()
        props.viewer_device_category = "tv"
        props.viewer_device_manufacturer = deviceInfo.GetModelDetails()["VendorName"]
        ' If GetModel() is invalid, try the specific model number
        seriesModel = deviceInfo.GetModel()
        if seriesModel = invalid
            seriesModel = deviceInfo.GetModelDetails()["ModelNumber"]
        end if
        props.viewer_device_model = seriesModel
        props.viewer_os_family = "Roku OS"
        props.viewer_os_version = firmwareVersion
        props.viewer_connection_type = _getConnectionType(deviceInfo)
        props.mux_api_version = m.MUX_API_VERSION
        props.player_mux_plugin_name = m.MUX_SDK_NAME
        props.player_mux_plugin_version = m.MUX_SDK_VERSION
        props.player_language_code = deviceInfo.GetCurrentLocale()
        videoMode = deviceInfo.GetVideoMode()
        props.player_width = m._getVideoPlaybackMetric(videoMode, "width")
        props.player_height = m._getVideoPlaybackMetric(videoMode, "height")
        props.player_is_fullscreen = m.PLAYER_IS_FULLSCREEN
        props.beacon_domain = m._getDomain(m.beaconUrl)

        ' We are moving towards using GUID style instance IDs
        props.player_instance_id = m._generateGUID()
        ' DEVICE INFO
        if m._Flag_useRandomMuxViewerId
            props.mux_viewer_id = m._generateGUID()
        else
            props.mux_viewer_id = deviceInfo.GetRIDA()
        end if
        return props
    end function

    ' called once per video'
    prototype._getVideoProperties = function(video as object) as object
        props = {}
        if video <> invalid
            if video.duration <> invalid and video.duration > 0
                m._videoSourceDuration = video.duration * 1000
            end if

            if video.videoFormat <> invalid and video.videoFormat <> ""
                m._videoSourceFormat = video.videoFormat
            end if
        end if

        return props
    end function

    ' Set called per video content'
    prototype._getVideoContentProperties = function(incomingContent as object) as object
        props = {}
        if incomingContent <> invalid
            content = incomingContent.GetFields()
            if content.title <> invalid and (type(content.title) = "String" or type(content.title) = "roString") and content.title <> ""
                props.video_title = content.title
            end if
            if content.TitleSeason <> invalid and (type(content.TitleSeason) = "String" or type(content.TitleSeason) = "roString") and content.TitleSeason <> ""
                props.video_series = content.TitleSeason
            end if
            if content.Director <> invalid and (type(content.Director) = "String" or type(content.Director) = "roString") and content.Director <> ""
                props.video_producer = content.Director
            end if
            if content.video_id <> invalid and (type(content.video_id) = "String" or type(content.video_id) = "roString") and content.video_id <> ""
                props.video_id = content.video_id
            end if
            if content.ContentType <> invalid
                if type(content.ContentType) = "roInt"
                    if content.ContentType = 1
                        props.video_content_type = "movie"
                    else if content.ContentType = 2
                        props.video_content_type = "series"
                    else if content.ContentType = 3
                        props.video_content_type = "season"
                    else if content.ContentType = 4
                        props.video_content_type = "episode"
                    else if content.ContentType = 5
                        props.video_content_type = "audio"
                    end if
                else
                    props.video_content_type = content.ContentType
                end if
            end if

            if (content.URL <> invalid and content.URL <> "")
                props.video_source_url = content.URL
                props.video_source_hostname = m._getHostname(content.URL)
                props.video_source_domain = m._getDomain(content.URL)
                m._videoSourceFormat = m._getVideoFormat(content.URL)
            end if

            if content.StreamFormat <> invalid and (type(content.StreamFormat) = "String" or type(content.StreamFormat) = "roString") and content.StreamFormat <> "(null)"
                props.video_source_mime_type = m._convertStreamFormat(content.StreamFormat)
            end if

            if content.Live <> invalid
                if content.Live = true
                    props.video_source_is_live = "true"
                else
                    props.video_source_is_live = "false"
                end if
            end if
            if content.Length <> invalid and content.Length > 0
                m._videoSourceDuration = content.Length * 1000
            end if
        end if

        return props
    end function

    ' called once per advert session'
    prototype._getAdvertProperties = function(adData as object) as object
        props = {}
        if adData <> invalid
            ad = adData.ad
            adIndex = adData.adIndex
            adTagUrl = adData.adTagUrl
            if ad <> invalid
                if adIndex <> invalid and adIndex = 1 'preroll only'
                    if ad.streams <> invalid
                        if ad.streams.count() > 0
                            if ad.streams[0].url <> invalid
                                adUrl = ad.streams[0].url
                                if adUrl <> invalid and adUrl <> ""
                                    props.view_preroll_ad_asset_hostname = m._getHostname(adUrl)
                                    props.view_preroll_ad_asset_domain = m._getDomain(adUrl)
                                end if
                            end if
                        end if
                    end if
                end if
            end if
            if adTagUrl <> invalid and adTagUrl <> ""
                props.view_preroll_ad_tag_hostname = m._getHostname(adTagUrl)
                props.view_preroll_ad_tag_domain = m._getDomain(adTagUrl)
            end if
        end if
        return props
    end function

    ' called once per event
    ' Note - when a number that _should_ be an integer is copied over,
    ' we force it into that format to help FormatJson do its job correctly
    ' later. Also, timestamps need to be `FormatJson`d immediately to
    ' try to make sure those don't get into scientific notation
    prototype._getDynamicProperties = function() as object
        props = {}
        if m.video <> invalid
            if m._Flag_isPaused = true
                props.player_is_paused = "true"
            else
                props.player_is_paused = "false"
            end if
            if m._playerTimeToFirstFrame = invalid and m.video.timeToStartStreaming <> invalid and m.video.timeToStartStreaming <> 0
                m._playerTimeToFirstFrame = Int(m.video.timeToStartStreaming * 1000)
                props.player_time_to_first_frame = m._playerTimeToFirstFrame
            end if
            if m._playerPlayheadTime <> invalid
                props.player_playhead_time = Int(m._playerPlayheadTime * 1000)
            end if
        end if
        if m.drmType <> invalid
            props.view_drm_type = m.drmType
        end if
        if m.droppedFrames <> invalid
            props.view_dropped_frames_count = m.droppedFrames
        end if
        if m._playerSequence <> invalid and m._playerSequence <> 0
            props.player_sequence_number = Int(m._playerSequence)
        end if
        if m._playerViewCount <> invalid and m._playerViewCount <> 0
            props.player_view_count = Int(m._playerViewCount)
        end if
        if m._viewSequence <> invalid and m._viewSequence <> 0
            props.view_sequence_number = Int(m._viewSequence)
        end if
        if m._viewID <> invalid and m._viewID <> ""
            props.view_id = m._viewID
        end if
        if m._startTimestamp <> invalid and m._startTimestamp <> 0
            props.player_start = FormatJson(m._startTimestamp)
        end if
        if m._viewStartTimestamp <> invalid and m._viewStartTimestamp <> 0
            props.view_start = FormatJson(m._viewStartTimestamp)
        end if
        if m._viewTimeToFirstFrame <> invalid and m._viewTimeToFirstFrame <> 0
            props.view_time_to_first_frame = Int(m._viewTimeToFirstFrame)
        end if
        if m._contentPlaybackTime <> invalid and m._contentPlaybackTime <> 0
            props.view_content_playback_time = Int(m._contentPlaybackTime)
            props.view_total_content_playback_time = Int(m._contentPlaybackTime)
        end if
        if m._viewWatchTime <> invalid and m._viewWatchTime <> 0
            props.view_watch_time = Int(m._viewWatchTime)
        end if
        if m._viewRebufferCount <> invalid
            props.view_rebuffer_count = Int(m._viewRebufferCount)
        end if
        if m._viewRebufferDuration <> invalid
            props.view_rebuffer_duration = Int(m._viewRebufferDuration)
        end if
        if m._viewRebufferPercentage <> invalid
            props.view_rebuffer_percentage = m._viewRebufferPercentage
        end if
        if m._viewRebufferFrequency! <> invalid
            props.view_rebuffer_frequency = m._viewRebufferFrequency!
        end if
        if m._viewSeekCount <> invalid
            props.view_seek_count = Int(m._viewSeekCount)
        end if
        if m._viewSeekDuration <> invalid
            props.view_seek_duration = Int(m._viewSeekDuration)
        end if
        if m._viewAdPlayedCount <> invalid
            props.view_ad_played_count = Int(m._viewAdPlayedCount)
        end if
        if m._viewPrerollPlayedCount <> invalid and m._viewPrerollPlayedCount > 0
            props.view_preroll_played = "true"
        else
            props.view_preroll_played = "false"
        end if
        if m._videoSourceFormat <> invalid
            props.video_source_format = m._videoSourceFormat
        end if
        if m._videoSourceDuration <> invalid
            props.video_source_duration = Int(m._videoSourceDuration)
        end if
        if m._viewMaxUpscalePercentage <> invalid
            props.view_max_upscale_percentage = m._viewMaxUpscalePercentage
        end if
        if m._viewMaxDownscalePercentage <> invalid
            props.view_max_downscale_percentage = m._viewMaxDownscalePercentage
        end if
        if m._viewTotalContentPlaybackTime <> invalid
            props.view_total_content_playback_time = m._viewTotalContentPlaybackTime
        end if
        if m._viewTotalUpscaling <> invalid
            props.view_total_upscaling = m._viewTotalUpscaling
        end if
        if m._viewTotalDownscaling <> invalid
            props.view_total_downscaling = m._viewTotalDownscaling
        end if
        if m._viewMinRequestThroughput <> invalid
            props.view_min_request_throughput = FormatJson(m._viewMinRequestThroughput)
        end if
        if m._viewAverageRequestThroughput <> invalid
            props.view_average_request_throughput = FormatJson(m._viewAverageRequestThroughput)
        end if
        if m._viewRequestCount <> invalid
            props.view_request_count = m._viewRequestCount
        end if
        if m._configProperties <> invalid and m._configProperties.player_init_time <> invalid
            playerInitTime = invalid
            if Type(m._configProperties.player_init_time) = "roString"
                playerInitTime = Val(m._configProperties.player_init_time)
            else if Type(m._configProperties.player_init_time) = "roFloat"
                playerInitTime = m._configProperties.player_init_time
            end if

            if playerInitTime <> invalid
                if playerInitTime > 0
                    props.player_startup_time = Int(m._startTimestamp - playerInitTime)
                    if m._viewTimeToFirstFrame <> invalid and m._viewTimeToFirstFrame <> 0
                        props.view_aggregate_startup_time = Int(m._viewTimeToFirstFrame + (m._startTimestamp - playerInitTime))
                    end if
                end if
            end if
        end if

        return props
    end function

    prototype._getDomain = function(url as string) as string
        domain = ""
        strippedUrl = url.Split("//")
        if strippedUrl.count() = 1
            url = strippedUrl[0]
        else if strippedUrl.count() > 1
            if strippedUrl[0].len() > 7
                url = strippedUrl[0]
            else
                url = strippedUrl[1]
            end if
        end if
        splitRegex = CreateObject("roRegex", "[\/|\?|\#]", "")
        strippedUrl = splitRegex.Split(url)
        if strippedUrl.count() > 0
            url = strippedUrl[0]
        end if
        domainRegex = CreateObject("roRegex", "([a-z0-9\-]+)\.([a-z0-9\-]+|[a-z0-9\-]{2}\.[a-z0-9\-]+)$", "i")
        matchResults = domainRegex.Match(url)
        if matchResults.count() > 0
            domain = matchResults[0]
        end if
        return domain
    end function

    prototype._getHostname = function(url as string) as string
        host = ""
        hostRegex = CreateObject("roRegex", "([a-z0-9\-]+)(\.)([a-z0-9\-\.]+)", "i")
        matchResults = hostRegex.Match(url)
        if matchResults.count() > 0
            host = matchResults[0]
        end if
        return host
    end function

    prototype._getHostnameAndPath = function(src as string) as string
        hostAndPath = src
        hostAndPathRegEx = CreateObject("roRegex", "^https?://", "")
        parts = hostAndPathRegEx.split(src)
        if parts <> invalid and parts.count() > 0
            if parts.count() > 1
                parts.shift()
            end if
            if parts.count() > 1
                hostAndPath = parts.join()
            else
                hostAndPath = parts[0]
            end if
            hostAndPathRegEx = CreateObject("roRegex", "\?|#", "")
            parts = hostAndPathRegEx.split(hostAndPath)
            if parts.count() > 1
                hostAndPath = parts[0]
            end if
        end if
        return hostAndPath
    end function

    prototype._convertStreamFormat = function(format as string) as string
        if format = "mp4"
            return "video/mp4"
        else if format = "wma"
            return "video/x-ms-wma"
        else if format = "mp3"
            return "audio/mpeg"
        else if format = "hls"
            return "application/x-mpegurl"
        else if format = "ism"
            return "application/vnd.ms-sstr+xml"
        else if format = "dash"
            return "application/dash+xml"
        else if format = "mkv"
            return "video/x-matroska"
        else if format = "mka"
            return "audio/x-matroska"
        else if format = "mks"
            return "video/x-matroska"
        else if format = "wmv"
            return "video/x-ms-wmv"
        else
            return format
        end if
    end function

    prototype._getVideoFormat = function(url as string) as string
        formatRegex = CreateObject("roRegex", "\*?\.([^\.]*?)(\?|\/$|$|#).*", "i")
        if formatRegex <> invalid
            extension = formatRegex.Match(url)
            if extension <> invalid and extension.count() > 1
                return extension[1]
            end if
        end if

        return "unknown"
    end function

    prototype._setCookieData = sub(data as object)
        cookie = _createRegistry()
        cookie.Write("UserRegistrationToken", data)
        cookie.Flush()
    end sub

    prototype._getCookieData = function() as dynamic
        cookie = _createRegistry()
        if cookie.Exists("UserRegistrationToken")
            return cookie.Read("UserRegistrationToken")
        end if
        return invalid
    end function

    prototype._minify = function(src as object) as object
        result = {}

        for each key in src
            if key = "_"
                result["__"] = src[key]
            else
                keyParts = key.split("_")
                newKey = ""
                s = keyParts.count()

                if s > 0
                    firstPart = keyParts[0]
                    if m._firstWords[firstPart] <> invalid
                        newKey = m._firstWords[firstPart]
                    else if firstPart <> ""
                        newKey = "_" + firstPart + "_"
                    end if
                end if

                for i = 1 to s - 1 step 1
                    nextPart = keyParts[i]

                    if nextPart <> ""
                        if m._subsequentWords[nextPart] <> invalid
                            newKey = newKey + m._subsequentWords[nextPart]
                        else if nextPart.len() > 0 and nextPart.toInt() > 0 and nextPart.toInt() = Int(nextPart.toInt())
                            ' Make sure the value is an integer, not decimal
                            newKey = newKey + nextPart
                        else
                            newKey = newKey + "_" + nextPart + "_"
                        end if
                    end if
                end for

                result[newKey] = src[key]
            end if
        end for

        return result
    end function

    prototype._createBeaconUrl = function(key as string, domain = "litix.io" as string) as string
        if m.manifestBaseUrl <> invalid and m.manifestBaseUrl <> ""
            return m.manifestBaseUrl
        end if
        keyRegex = CreateObject("roRegex", "^[a-z0-9]+$", "i")
        result = "https://"
        subdomain = "img"
        if keyRegex <> invalid
            keyValid = keyRegex.isMatch(key)
            if keyValid = true
                subdomain = key
            end if
        end if
        result = result + subdomain
        result = result + "." + domain

        return result
    end function

    prototype._generateShortID = function() as string
        randomNumber = Rnd(0) * 2176782336
        randomNumber = randomNumber << 2
        shortID = Right(StrI(randomNumber, 36), 6)
        return shortID
    end function

    prototype._getVideoPlaybackMetric = function(videoMode as string, metricType as string) as string
        result = ""
        metrics = {
            "480i": { width: "720", height: "480", aspect: "4:3", refresh: "60 Hz", depth: "8 Bit" },
            "480p": { width: "720", height: "480", aspect: "4:3", refresh: "60 Hz", depth: "8 Bit" },
            "576i25": { width: "720", height: "576", aspect: "4:3", refresh: "25 Hz", depth: "8 Bit" },
            "576p50": { width: "720", height: "576", aspect: "4:3", refresh: "50 Hz", depth: "8 Bit" },
            "576p60": { width: "720", height: "576", aspect: "4:3", refresh: "60 Hz", depth: "8 Bit" },
            "720p50": { width: "1280", height: "720 ", aspect: "16:9", refresh: "50 Hz", depth: "8 Bit" },
            "720p": { width: "1280", height: "720 ", aspect: "16:9", refresh: "60 Hz", depth: "8 Bit" },
            "1080i50": { width: "1920", height: "1080", aspect: "16:9", refresh: "50 Hz", depth: "8 Bit" },
            "1080i": { width: "1920", height: "1080", aspect: "16:9", refresh: "60 Hz", depth: "8 Bit" },
            "1080p24": { width: "1920", height: "1080", aspect: "16:9", refresh: "24 Hz", depth: "8 Bit" },
            "1080p25": { width: "1920", height: "1080", aspect: "16:9", refresh: "25 Hz", depth: "8 Bit" },
            "1080p30": { width: "1920", height: "1080", aspect: "16:9", refresh: "30 Hz", depth: "8 Bit" },
            "1080p50": { width: "1920", height: "1080", aspect: "16:9", refresh: "50 Hz", depth: "8 Bit" },
            "1080p": { width: "1920", height: "1080", aspect: "16:9", refresh: "60 Hz", depth: "8 Bit" },
            "2160p25": { width: "3840", height: "2160", aspect: "16:9", refresh: "25 Hz", depth: "8 Bit" },
            "2160p24": { width: "3840", height: "2160", aspect: "16:9", refresh: "24 Hz", depth: "8 Bit" },
            "2160p30": { width: "3840", height: "2160", aspect: "16:9", refresh: "30 Hz", depth: "8 Bit" },
            "2160p50": { width: "3840", height: "2160", aspect: "16:9", refresh: "50 Hz", depth: "8 Bit" },
            "2160p60": { width: "3840", height: "2160", aspect: "16:9", refresh: "60 Hz", depth: "8 Bit" },
            "2160p24b10": { width: "3840", height: "2160", aspect: "16:9", refresh: "24 Hz", depth: "10 Bit" },
            "2160p25b10": { width: "3840", height: "2160", aspect: "16:9", refresh: "25 Hz", depth: "10 Bit" },
            "2160p50b10": { width: "3840", height: "2160", aspect: "16:9", refresh: "50 Hz", depth: "10 Bit" },
            "2160p30b10": { width: "3840", height: "2160", aspect: "16:9", refresh: "30 Hz", depth: "10 Bit" },
            "2160p60b10": { width: "3840", height: "2160", aspect: "16:9", refresh: "60 Hz", depth: "10 Bit" },
            "4320p60": { width: "7680", height: "4320", aspect: "16:9", refresh: "60 Hz", depth: "12 Bit" },
            "4320p60b10": { width: "7680", height: "4320", aspect: "16:9", refresh: "60 Hz", depth: "12 Bit" }
        }
        if metrics[videoMode] <> invalid
            modeMetrics = metrics[videoMode]
            if modeMetrics[metricType] <> invalid
                result = modeMetrics[metricType]
            end if
        end if
        return result
    end function

    prototype._generateGUID = function() as string
        pattern = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
        randomizeX = function() as string
            return StrI(Rnd(0) * 16, 16)
        end function
        randomizeY = function() as string
            randomNumber = Rnd(0) * 16
            randomNumber = randomNumber + 3
            if randomNumber >= 16
                randomNumber = 8
            end if
            return StrI(randomNumber, 16)
        end function
        patternArray = pattern.split("")
        viewId = ""
        for each char in patternArray
            if char = "x"
                viewId = viewId + randomizeX()
            else if char = "y"
                viewId = viewId + randomizeY()
            else
                viewId = viewId + char
            end if
        end for
        return viewId
    end function

    prototype._logBeacon = sub(eventArray as object, title = "BEACON" as string)
        if m.debugBeacons <> "full" and m.debugBeacons <> "partial" then return
        fullEvent = (m.debugBeacons = "full")
        tot = m.loggingPrefix + title + " (" + eventArray.count().toStr() + ") [ "
        for each evt in eventArray
            if fullEvent = false
                if evt <> invalid
                    tot = tot + " " + evt.event
                end if
            else
                tot = tot + "{"
                for each prop in evt
                    tot = tot + prop + ":" + evt[prop].toStr() + ", "
                end for
                tot = Left(tot, len(tot) - 2)
                tot = tot + "} "
            end if
        end for
        tot = tot + " ]"
        print tot
    end sub

    prototype._logEvent = sub(event = {} as object, subtype = "" as string, title = "EVENT" as string)
        if m.debugEvents = "none" then return
        tot = m.loggingPrefix + title + " " + event.event
        if m.debugEvents = "full"
            tot = tot + "{"
            for each prop in event
                if event[prop] <> invalid
                    tot = tot + prop + ":" + event[prop].toStr() + ", "
                end if
            end for
            tot = Left(tot, len(tot) - 2)
            tot = tot + "} "
        end if
        print tot
    end sub

    prototype._getDeviceInfo = function() as object
        return _createDeviceInfo()
    end function

    prototype._getAppInfo = function() as object
        return _createAppInfo()
    end function

    prototype._getDateTime = function() as object
        return CreateObject("roDateTime")
    end function

    prototype._firstWords = {
        "property": "a",
        "env": "a", ' account
        "beacon": "b",
        "custom": "c",
        "ad": "d",
        "event": "e",
        "experiment": "f", ' nothing better to use...
        "internal": "i",
        "mux": "m",
        "response": "n",
        "player": "p",
        "request": "q",
        "retry": "r", ' placeholder for beacons adding retry counts
        "session": "s",
        "timestamp": "t",
        "viewer": "u", ' user
        "video": "v",
        "page": "w", ' web page
        "view": "x",
        "sub": "y" ' cause nowhere else to fit it
    }

    prototype._subsequentWords = {
        "ad": "ad",
        "affiliate": "af",
        "aggregate": "ag",
        "api": "ap",
        "application": "al",
        "audio": "ao",
        "architecture": "ar",
        "asset": "as",
        "autoplay": "au",
        "average": "av",
        "bitrate": "bi",
        "brand": "bn",
        "break": "br",
        "browser": "bw",
        "bytes": "by",
        "business": "bz",
        "cached": "ca",
        "cancel": "cb",
        "codec": "cc",
        "code": "cd",
        "category": "cg",
        "changed": "ch",
        "client": "ci",
        "clicked": "ck",
        "canceled": "cl",
        "config": "cn",
        "count": "co",
        "counter": "ce",
        "complete": "cp",
        "creator": "cq",
        "creative": "cr",
        "captions": "cs",
        "content": "ct",
        "current": "cu",
        "connection": "cx",
        "context": "cz",
        "downscaling": "dg",
        "domain": "dm",
        "cdn": "dn",
        "downscale": "do",
        "drm": "dr",
        "dropped": "dp",
        "duration": "du",
        "device": "dv",
        "dynamic": "dy",
        "enabled": "eb",
        "encoding": "ec",
        "edge": "ed",
        "end": "en",
        "engine": "eg",
        "embed": "em",
        "error": "er",
        "experiments": "ep",
        "errorcode": "es",
        "errortext": "et",
        "event": "ee",
        "events": "ev",
        "expires": "ex",
        "exception": "ez",
        "failed": "fa",
        "first": "fi",
        "family": "fm",
        "format": "ft",
        "fps": "fp",
        "frequency": "fq",
        "frame": "fr",
        "fullscreen": "fs",
        "has": "ha",
        "holdback": "hb",
        "headers": "he",
        "host": "ho",
        "hostname": "hn",
        "height": "ht",
        "id": "id",
        "init": "ii",
        "instance": "in",
        "ip": "ip",
        "is": "is",
        "key": "ke",
        "language": "la",
        "labeled": "lb",
        "level": "le",
        "live": "li",
        "loaded": "ld",
        "load": "lo",
        "lists": "ls",
        "latency": "lt",
        "max": "ma",
        "media": "md",
        "message": "me",
        "manifest": "mf",
        "mime": "mi",
        "midroll": "ml",
        "min": "mm",
        "manufacturer": "mn",
        "model": "mo",
        "mux": "mx",
        "newest": "ne",
        "name": "nm",
        "number": "no",
        "on": "on",
        "origin": "or",
        "os": "os",
        "paused": "pa",
        "playback": "pb",
        "producer": "pd",
        "percentage": "pe",
        "played": "pf",
        "program": "pg",
        "playhead": "ph",
        "plugin": "pi",
        "preroll": "pl",
        "playing": "pn",
        "poster": "po",
        "pip": "pp",
        "preload": "pr",
        "position": "ps",
        "part": "pt",
        "property": "py",
        "pop": "px",
        "plan": "pz",
        "rate": "ra",
        "requested": "rd",
        "rebuffer": "re",
        "rendition": "rf",
        "range": "rg",
        "remote": "rm",
        "ratio": "ro",
        "response": "rp",
        "request": "rq",
        "requests": "rs",
        "sample": "sa",
        "skipped": "sd",
        "session": "se",
        "shift": "sh",
        "seek": "sk",
        "stream": "sm",
        "source": "so",
        "sequence": "sq",
        "series": "sr",
        "status": "ss",
        "start": "st",
        "startup": "su",
        "server": "sv",
        "software": "sw",
        "severity": "sy",
        "tag": "ta",
        "tech": "tc",
        "text": "te",
        "target": "tg",
        "throughput": "th",
        "time": "ti",
        "total": "tl",
        "to": "to",
        "title": "tt",
        "type": "ty",
        "upscaling": "ug",
        "universal": "un",
        "upscale": "up",
        "url": "ur",
        "user": "us",
        "variant": "va",
        "viewed": "vd",
        "video": "vi",
        "version": "ve",
        "view": "vw",
        "viewer": "vr",
        "width": "wd",
        "watch": "wa",
        "waiting": "wt"
    }

    ' ' //////////////////////////////////////////////////////////////
    ' ' UTILS METHODS
    ' ' //////////////////////////////////////////////////////////////

    prototype._min = function(a, b) as object
        if a = invalid then a = 0
        if b = invalid then b = 0

        if a < b then
            return a
        else
            return b
        end if
    end function

    prototype._max = function(a, b) as object
        if a = invalid then a = 0
        if b = invalid then b = 0

        if a < b then
            return b
        else
            return a
        end if
    end function

    prototype._safeAdd = function(var, addValue) as object
        if var = invalid then
            return addValue
        else
            return var + addValue
        end if
    end function

    return prototype
end function
