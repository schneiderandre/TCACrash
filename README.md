## This Sample contains a setup and flow which leads to a crash due to the deletion of a row, while the dismissal is still in progress.
 
 [List] -> [Row] -> [Detail]
 
 The list presents multiple rows, each row can present a Detail sheet whith a delete button.
 
 ### Actual behavior:
 
 1. The detail sheets delete button is tapped
 2. Detail sends a delegate action to the parent (Row)
 3. Row nils out the destination
 4. Row sends delegate action to the parent (List)
 5. The List deletes the row from the state.
 6. Crash
 
 ### Expected behavior:
 There should be no crash, and the view should dismiss properly
 
 ### Additional Info

 the _StoreCollection has a Todo from 29th of November stating the following TODO:
 
 "TODO: Should this be an entire snapshot of store state? `IdentifiedArray<ID, State>`?"
 
 To prior <= 1.5 I used the follwing in the Row reducer:
 
```swift
case .didTapDelete:
    state.destination = nil
    /// Uses `.run` instead of `.send`. `.send` causes an issue where the rows id is deleted
    /// before it can successfully be dismissed by a parent.
    return .run { send in
        await send(.delegate(.deleteRowTapped))
    }
 }
 ```
 
 This worked, but was already a workaround back then.
