-----------------------------------------------------------------------
-- Improved Version Checker for Rexshack-RedM Resources
----------------------------------------------------------------------- 

local resourceName = GetCurrentResourceName()
local githubRawBase = 'https://raw.githubusercontent.com/Rexshack-RedM/rsg-versioncheckers/main/'

local function printLog(type, message)
    local color = (type == 'success' and '^2') or (type == 'warning' and '^3') or '^1'
    print(('[%s]%s %s^7'):format(resourceName, color, message))
end

-- Simple semantic version comparison (supports major.minor.patch)
local function isVersionOutdated(current, latest)
    local function splitVersion(v)
        local major, minor, patch = v:match("(%d+)%.(%d+)%.(%d+)")
        if major then
            return {tonumber(major), tonumber(minor) or 0, tonumber(patch) or 0}
        end
        return {0, 0, 0} -- fallback
    end

    local c = splitVersion(current)
    local l = splitVersion(latest)

    for i = 1, 3 do
        if l[i] > c[i] then return true
        elseif l[i] < c[i] then return false
        end
    end
    return false -- equal
end

local function CheckVersion()
    local currentVersion = GetResourceMetadata(resourceName, 'version')
    if not currentVersion then
        printLog('error', locale('ver_read_failed'))
        return
    end

    local versionUrl = githubRawBase .. resourceName .. '/version.txt'

    PerformHttpRequest(versionUrl, function(statusCode, remoteVersion, headers)
        if statusCode ~= 200 then
            printLog('error', locale('ver_http_failed'):format(statusCode))
            return
        end

        if not remoteVersion or remoteVersion == '' then
            printLog('error', locale('ver_empty_data'))
            return
        end

        -- Trim whitespace/newlines
        remoteVersion = remoteVersion:gsub('%s+$', '')

        if currentVersion == remoteVersion then
            printLog('success', locale('ver_latest'))
            return
        end

        if isVersionOutdated(currentVersion, remoteVersion) then
            printLog('error', locale('ver_outdated'):format(remoteVersion))
            printLog('error', locale('ver_download'):format('https://github.com/Rexshack-RedM/' .. GetCurrentResourceName()))
        else
            printLog('warning', locale('ver_newer'):format(currentVersion, remoteVersion))
        end
    end, 'GET')
end

--------------------------------------------------------------------------------------------------
-- Start version check on resource start
--------------------------------------------------------------------------------------------------
CheckVersion()