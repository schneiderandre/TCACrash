import ComposableArchitecture
import SwiftUI

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
