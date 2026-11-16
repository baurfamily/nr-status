import AppIntents
import WidgetKit

struct PublishedWidgetEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Published Widget"
    static var defaultQuery = PublishedWidgetQuery()

    let id: String
    let name: String
    let sourceName: String

    init(_ widget: PublishedWidget) {
        id = widget.id.uuidString
        name = widget.name
        sourceName = widget.sourceName
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(sourceName)")
    }
}

struct PublishedWidgetQuery: EntityStringQuery {
    typealias Result = IntentItemCollection<PublishedWidgetEntity>

    func entities(for identifiers: [String]) async throws -> [PublishedWidgetEntity] {
        let registry = try WidgetRegistry.shared()
        return try identifiers.compactMap { value in
            guard let id = UUID(uuidString: value), let widget = try registry.widget(id: id) else { return nil }
            return PublishedWidgetEntity(widget)
        }
    }

    func suggestedEntities() async throws -> Result {
        collection(try WidgetRegistry.shared().widgets())
    }

    func entities(matching string: String) async throws -> Result {
        collection(try WidgetRegistry.shared().widgets().filter {
            $0.name.localizedCaseInsensitiveContains(string) || $0.sourceName.localizedCaseInsensitiveContains(string)
        })
    }

    private func collection(_ widgets: [PublishedWidget]) -> Result {
        Result(sections: PublishedWidgetGroup.grouping(widgets).map { group in
            IntentItemSection("\(group.sourceName)", items: group.widgets.map(PublishedWidgetEntity.init))
        })
    }
}

struct WorkbookWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Workbook Widget"
    static var description = IntentDescription("Display a chart or Markdown cell published from NR Status.")

    @Parameter(title: "Published Widget")
    var widget: PublishedWidgetEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$widget)")
    }
}
