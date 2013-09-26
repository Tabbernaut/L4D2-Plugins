
/*
    idea:
        for any map that has a camping/holdout event (say SF1 ferry, Par4 float, DT3 church door):
        turn a configured fraction of any map's distance into bonus points
        those points are awarded over time: 0 when holdout event starts, 100% when it ends 
        (end = as soon as survivors can take action again)
        
    execution:
        build in forwards for:
            OnHoldoutDistanceRecalculated()     tells other plugins what the new distance should be
            OnHoldoutEventStart()               the instant the camp-and-wait-event is started
            OnHoldoutEventEnd()                 the instant the survivors can do something again
            OnHoldoutPointsUpdated()            every time in between start/end, every increment
                                                of the bonus holdout points earned
                                                
        cvars to change
            - whether it applies the points itself -- or just sends the forwards with information
            - whether it reports the points itself
            
        mapinfo
            for each map that has a holdout event, give:
                holdoutFraction         the fraction of the map's total distance that should be
                holdoutEvent            some indication of how the event can be detected
                                        hammerids for buttons, events being fired.. figure out how
                                        to detect things
            + multiple events possible per map?
            
            
        considerations
            - should check map distance late enough so that custom distance changes / random distance
              is applied.
            
            
    dependency
        penalty_bonus
*/
