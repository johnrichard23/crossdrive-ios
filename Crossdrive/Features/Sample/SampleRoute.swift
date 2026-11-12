/// Where the sample feature can push to. Each feature keeps its own routes.
enum SampleRoute: Hashable {
    case detail(Item.ID)
}
