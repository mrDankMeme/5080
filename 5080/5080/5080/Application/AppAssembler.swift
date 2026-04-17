
import Swinject

enum AppAssembler {
    static func make() -> Assembler {
        Assembler([
            ServicesAssembly()
        ])
    }
}
