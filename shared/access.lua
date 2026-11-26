-- job / gang restrictions, used by both the client and the server
function HasAnimationAccess(animation, data)
    if not animation.Jobs and not animation.Gangs then return true end
    data = data or {}

    local function matches(list, group)
        local minimum = list and group and list[group.name]
        return minimum ~= nil and (tonumber(group.grade and group.grade.level) or 0) >= minimum
    end

    if matches(animation.Jobs, data.job) and (not animation.DutyOnly or data.job.onduty) then return true end
    return matches(animation.Gangs, data.gang)
end
