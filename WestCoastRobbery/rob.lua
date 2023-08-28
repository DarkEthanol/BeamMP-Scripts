-- Adjustable Parameters
local randomTimeVariation = 10;
local cooldownSeconds = 60;

local warningTextColour = "^b";
-- End


local currentRobber = nil;
local currentLocation;

local score = 0;
local robbedCount = 0;

local timerCountdown;
local locationsRobbed = {};

function onInit()
    print("Rob Command Plugin Loaded");
    MP.RegisterEvent("onChatMessage", "onChatMessage");
    MP.RegisterEvent("RobTimer", "RobLocation");
    MP.RegisterEvent("TimeoutTimer", "FinishAction");
    MP.CancelEventTimer("RobTimer");
    MP.CancelEventTimer("TimeoutTimer");
end

function onChatMessage(senderID, name, message)
    if message:startsWith("/rob") then
        local command = string.match(message, "/rob (.*)");
        if command == nil then           
            -- Verify no other location is been robbed currently
            if currentRobber ~= nil then
                MP.SendChatMessage(senderID, "Only one location can be robbed at once!");
                return 1;
            end

            local robbingLocation = GetRobabbleLocation(senderID);
            if robbingLocation ~= nil then
                currentRobber = { playerId = senderID, name = name }
                
                if locationsRobbed[robbingLocation.name] ~= nil and locationsRobbed[robbingLocation.name].time + cooldownSeconds > os.clock() then
                    local seconds = math.floor(os.clock() - locationsRobbed[robbingLocation.name].time);
                    MP.SendChatMessage(senderID, "This location was last robbed " .. seconds .. " seconds ago, please wait " .. cooldownSeconds - seconds .. " seconds before robbing again.");
                    FinishAction();
                    return 1;
                end
                BeginRob(robbingLocation);
            else
                MP.SendChatMessage(senderID, "You are not near any robbable location.");
            end
        elseif command == "locations" then
            PrintLocations(senderID);
        elseif command == "score" then
            PrintRobCount(senderID);
        elseif command == "reset" then
            FinishAction();
            score = 0;
            robbedCount = 0;
            locationsRobbed = {};
            MP.SendChatMessage(-1, "Rob reset!");
        elseif command == "robbed" then
            PrintRobbedLocations(senderID);
        else
            MP.SendChatMessage(senderID, command .. " is not a command. Please use /rob locations, score, reset or none")
        end

        return 1;
    else
        return 0;
    end
end

function GetRobabbleLocation(senderID)
    local playerPos = GetPlayerLocation(senderID);
    if playerPos == nil then
        return;
    end

    -- Check if player is within range of a location
    for locationName, locationData in pairs(Locations) do
        for _, coords in pairs(locationData.coords) do
            local  distance = GetDistanceFromLocation(playerPos, coords);

            if distance <= coords.range then
                return { name = locationName, location = {id = locationData.id, coords = coords, robTime = locationData.robTime, score = locationData.score} };
            end
        end
    end
    return nil;
end


function BeginRob(robLocation)
    if robLocation.location.robTime < 0 then
        MP.SendChatMessage(-1, warningTextColour .. currentRobber.name .. " has robbed " .. robLocation.name .. "!");
        return nil;
    end

    timerCountdown = math.random(0, randomTimeVariation) + robLocation.location.robTime;
    MP.SendChatMessage(-1, warningTextColour .. "Someone is robbing " .. robLocation.name .. "!");
    MP.SendChatMessage(currentRobber.playerId, "Robbing will take " .. timerCountdown .. " seconds!");

    currentLocation = robLocation;

    MP.CreateEventTimer("TimeoutTimer", (timerCountdown + 5) * 1000 );
    MP.CreateEventTimer("RobTimer", 1000);
end

function PrintRobCount(senderID)
    if robbedCount == 1 then
        MP.SendChatMessage(senderID, warningTextColour .. robbedCount .. " location has been robbed!" )
    elseif robbedCount == 0 then
        MP.SendChatMessage(senderID, warningTextColour .. "No locations have been robbed!" )
    else
        MP.SendChatMessage(senderID, warningTextColour .. robbedCount .. " locations have been robbed!" )
    end
    MP.SendChatMessage(senderID, warningTextColour .. "The current score is: " .. score )
end

function PrintLocations(senderID)
    MP.SendChatMessage(senderID, "-----Locations-----");
    for location_name, location_data in pairs(Locations) do
        MP.SendChatMessage(senderID, "Name: " .. location_name .. " - Score: " .. location_data.score .. " - Time: " ..  location_data.robTime);
    end
    return 1
end

function PrintRobbedLocations(senderID)
    MP.SendChatMessage(senderID, "-----Robbed Locations-----");
    for location_name, location_data in pairs(locationsRobbed) do
        local value = " time.";
        if location_data.count > 1 then
            value = " times.";
        end
        MP.SendChatMessage(senderID, location_name .. " has been robbed " .. location_data.count .. value);
    end
    return 1
end

function RobLocation()
    if timerCountdown < 1 then
        MP.SendChatMessage(-1, warningTextColour .. currentRobber.name .. " has robbed " .. currentLocation.name .. "!");
        robbedCount = robbedCount + 1;
        score = score + currentLocation.location.score;
        if locationsRobbed[currentLocation.name] ~= nil then
            locationsRobbed[currentLocation.name] = { time = os.clock(), count = locationsRobbed[currentLocation.name].count + 1 };
        else
            locationsRobbed[currentLocation.name] = { time = os.clock(), count = 1 };
        end
        PrintRobCount(-1);
        FinishAction();
        return;
    end

    local playerPos = GetPlayerLocation(currentRobber.playerId);
    if playerPos == nil then
        FinishAction();
        return
    end 

    local distance = GetDistanceFromLocation(playerPos, currentLocation.location.coords);
        if distance > currentLocation.location.coords.range then
            MP.SendChatMessage(currentRobber.playerId, warningTextColour .. "You failed to rob the " .. currentLocation.name .. "!");
            MP.SendChatMessage(-1, warningTextColour .. "They failed to rob the " .. currentLocation.name .. "!");
            FinishAction();
            return;
        end
    MP.SendChatMessage(currentRobber.playerId, timerCountdown .. " seconds remaining!");

    timerCountdown = timerCountdown - 1;
end


function FinishAction()
    timerCountdown = 0;
    currentRobber = nil;
    currentLocation = nil;
    MP.CancelEventTimer("RobTimer");
    MP.CancelEventTimer("TimeoutTimer");
end

function GetPlayerLocation(playerId)

    local vehicles = MP.GetPlayerVehicles(playerId);
    local vid = next(vehicles);
    local position, errorStr = MP.GetPositionRaw(playerId, vid);

    if not position then
        MP.SendChatMessage(playerId, "An error occurred while getting your position.");
        return nil;
    end 

    return {x = position.pos[1], y = position.pos[2], z = position.pos[3]};
end

function GetDistanceFromLocation(playerLocation, robbableLocation)
    local dx, dy, dz = robbableLocation.x - playerLocation.x, robbableLocation.y - playerLocation.y, robbableLocation.z - playerLocation.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
end

function string:startsWith(start)
    return self:sub(1, #start) == start
end