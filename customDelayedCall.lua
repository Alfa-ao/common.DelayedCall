--[[ 
common.RegisterFrameHandler

Для пользовательских аддонов имеются ограничения

- Внутри FrameHandler нельзя слать ивенты, писать в лог, работать с конфигом.

- При requireHit == false имеется ограничение: 
время исполнения хендлера не должно превышать 3мс, если это правило будет нарушено 100 раз фича будет залочена для аддона до рестарта игры.
 ]]


local CustomDelayedCall = {}
local pendingTasks = {}
local taskIdCounter = 0
local isFrameHandlerRegistered = false

--- Функция-обвертка, которая будет вызываться каждый кадр.
--- @param elapsedMs number Время, прошедшее с прошлого кадра.
--- @param timeMs number Общий глобальный таймер.
local function OnFrameUpdate( elapsedMs, timeMs )
    local completedTasks = {}
    
    for taskId, task in pairs( pendingTasks ) do
        if timeMs >= task.targetTime then
            task.func( table.unpack( task.args ) )
            table.insert( completedTasks, taskId )
        end
    end
    
    for _, taskId in ipairs( completedTasks ) do
        pendingTasks[ taskId ] = nil
    end
    
    if next( pendingTasks ) == nil and isFrameHandlerRegistered then
        common.UnRegisterFrameHandler()
        isFrameHandlerRegistered = false
    end
end

--- Альтернатива "common.DelayedCall".
--- @param delayMs number Задержка в миллисекундах.
--- @param func function Функция для вызова. Если выполнение этой функции превысит 3 мс на протяжении 100 кадров, то функционал будет заблокирован для аддона до рестарта игры.
--- @param ... any Аргументы для функции.
--- @return number taskId Идентификатор задачи.
function CustomDelayedCall.Call( delayMs, func, ... )
    if type( func ) ~= "function" then
        error( "CustomDelayedCall.Call: func argument must be a function" )
    end
    
    if not isFrameHandlerRegistered then
        -- requireHit = false
        common.RegisterFrameHandler( OnFrameUpdate, false )
        isFrameHandlerRegistered = true
    end

    taskIdCounter = taskIdCounter + 1
    local taskId = taskIdCounter
    
    pendingTasks[ taskId ] = {
        targetTime = common.GetAbsTimeMs() + delayMs,
        func = func,
        args = { ... }
    }

    return taskId
end

--- Альтернатива "common.CancelDelayedCall".
--- @param taskId number Идентификатор задачи.
function CustomDelayedCall.Cancel( taskId )
    if pendingTasks[taskId] then
        pendingTasks[taskId] = nil
    end
end





------------------------------------------------
-----------------test--------------------------
------------------------------------------------


-- вызов через 30 секунд. В mods.txt появится ошибка: "Game::LuaAvatarStartInspect: cannot inspect player"
-- Это значит что "CustomDelayedCall" отработал.
local taskId = CustomDelayedCall.Call( 30000, function() 
    avatar.StartInspect( avatar.GetId() ) 
end )

-- Если нужно отменить до срабатывания:
--DelayedCall.Cancel( taskId )
