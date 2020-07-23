# PrioRollManager

This is a simple WoW Clasic addon that supports the master looter of raids that use a simple roll-based loot distribution. It is geared towards raids that let the master looter pick up all items and trade them to the winners during the run. When the master looter posts an item for rolling, the addon collects all roll messages and announces the winner after 30 seconds.

Features:
* Offers flexibility by sorting results by roller's upper roll bound (enabling off/main-spec rolls or prio rolls).
* Side window that lists all loot and contains buttons to quickly start a roll or trade the item to the winner.

Commands:
```
/prm - Shows the help message
/prm start [item] - Starts a 30 second roll for item [item]
/prm cancel - Cancels the current roll
/prm show - Shows the side window
/prm hide - Hides the side window
```