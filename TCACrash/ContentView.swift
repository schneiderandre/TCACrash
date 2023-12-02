import ComposableArchitecture
import SwiftUI

/*
This Sample contains a flow which leads to a crash due to the deletion of a row, while the dismissal is still in progress.
 
 [List] -> [Row] -> [Detail]
 
 The list presents multiple rows, each row can present a Detail sheet whith a delete button.
 
 Actual behavior:
 
 1. The detail sheets delete button is tapped
 2. Detail sends a delegate action to the parent (Row)
 3. Row nils out the destination
 4. Row sends delegate action to the parent (List)
 5. The List deletes the row from the state.
 6. Crash
 
 Expected behavior:
 There should be no crash, and the view should dismiss properly
 
 Additional Info:

 the _StoreCollection has a Todo from 29th of November stating the following TODO:
 
 "TODO: Should this be an entire snapshot of store state? `IdentifiedArray<ID, State>`?"
 
 To prior <= 1.5 I used the follwing in the Row reducer:
 
 """
 state.destination = nil
 /// Uses `.run` instead of `.send`. `.send` causes an issue where the rows id is deleted
 /// before it can successfully be dismissed by a parent.
 return .run { send in
    await send(.delegate(.deleteRowTapped))
 }
 """
 
 This worked, but was already a workaround back then.
*/



struct ContentView: View {
    let store = Store(
        initialState: RowList.State(rows: [
            .init(name: "One", id: .init()),
            .init(name: "Two", id: .init()),
            .init(name: "Three", id: .init()),
            .init(name: "Four", id: .init())
        ])
    ) {
        RowList()._printChanges()
    }
    
    var body: some View {
        ListView(store: store)
    }
}

@Reducer
struct RowList {
    @ObservableState
    struct State {
        var rows: IdentifiedArrayOf<Row.State> = []
    }
    
    enum Action {
        case rows(IdentifiedActionOf<Row>)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .rows(.element(id: uuid, action: .delegate(delegate))):
                switch delegate {
                case .deleteRowTapped:
                    state.rows.remove(id: uuid)
                    return .none
                }
            case .rows:
                return .none
            }
        }
        .forEach(\.rows, action: \.rows) {
            Row()
        }
    }
}

struct ListView: View {
    let store: StoreOf<RowList>
    
    var body: some View {
        List {
            ForEach(store.scope(
                state: \.rows,
                action: \.rows
            ),
                    content: RowView.init(store:)
            )
        }
    }
}

@Reducer
struct Row {
    @ObservableState
    struct State: Identifiable {
        @PresentationState var destination: Destination.State?
        let name: String
        let id: UUID
    }
    
    enum Action {
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case showDetailButtonTapped
        
        @CasePathable
        public enum Delegate: Sendable {
            case deleteRowTapped
        }
    }
    
    @Reducer
    public struct Destination {
        public enum State: Equatable {
            case detail(Detail.State)
        }
        
        public enum Action {
            case detail(Detail.Action)
        }
        
        public var body: some ReducerOf<Self> {
            Scope(state: \.detail, action: \.detail) {
                Detail()
            }
        }
    }
    
    var body: some ReducerOf<Row> {
        Reduce { state, action in
            switch action {
            case .showDetailButtonTapped:
                state.destination = .detail(.init(title: state.name))
                return .none
            case let .destination(.presented(.detail(.delegate(delegate)))):
                switch delegate {
                case .didTapDelete:
                    state.destination = nil
                    return .send(.delegate(.deleteRowTapped))
                }
            case .destination:
                return .none
            case .delegate:
                return .none
            }
        }.ifLet(\.$destination, action: \.destination) {
            Destination()
        }
    }
}

struct RowView: View {
    @State var store: StoreOf<Row>
    
    var body: some View {
        HStack {
            Text(store.name)
            Button("Show Detail") {
                store.send(.showDetailButtonTapped)
            }.buttonStyle(.bordered)
        }
        .sheet(
            item: $store.scope(state: \.destination?.detail, action: \.destination.detail),
            content: DetailView.init
        )
    }
}

@Reducer
struct Detail {
    
    @ObservableState
    struct State: Equatable {
        let title: String
    }
    
    enum Action {
        case deleteButtonTapped
        case delegate(Delegate)
        
        @CasePathable
        public enum Delegate: Sendable {
            case didTapDelete
        }
    }
    
    var body: some ReducerOf<Detail> {
        Reduce { state, action in
            switch action {
            case .deleteButtonTapped:
                return .send(.delegate(.didTapDelete))
            case .delegate:
                return .none
            }
            
        }
    }
}

struct DetailView: View {
    let store: StoreOf<Detail>
    
    var body: some View {
        Text(store.title)
        Button("Delete") {
            store.send(.deleteButtonTapped)
        }.buttonStyle(.borderedProminent)
    }
}
