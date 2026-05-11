add_library(LegendaryKit STATIC
    LegendaryFS.swift
    User.swift
    Library.swift
    Models.swift
    Paths.swift
    WineDetector.swift
    LaunchParameters.swift
    SubProcess/Runner/LegendaryRunner.swift
    SubProcess/Commands/ListCommand.swift
    SubProcess/Commands/BaseTypes.swift
    SubProcess/Commands/LegendaryCommand.swift
    SubProcess/Commands/AuthCommand.swift
    SubProcess/Commands/ImportCommand.swift
    SubProcess/Commands/InstallCommand.swift
    SubProcess/Commands/InfoCommand.swift
)

target_link_libraries(LegendaryKit
    PUBLIC
        EpicKit
    PRIVATE
        Subprocess    
        SystemPackage
)
