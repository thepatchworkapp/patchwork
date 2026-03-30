import Foundation

let sourcePath = "/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Design/tasker-paywall-candidates/candidate-6-orbit-lock.png"
let outputPath = "/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Assets.xcassets/TaskerPaywallHero.imageset/tasker-paywall-hero.png"

let fileManager = FileManager.default

guard fileManager.fileExists(atPath: sourcePath) else {
    fatalError("Missing chosen paywall hero source image at \(sourcePath)")
}

if fileManager.fileExists(atPath: outputPath) {
    try fileManager.removeItem(atPath: outputPath)
}

try fileManager.copyItem(atPath: sourcePath, toPath: outputPath)
print("Wrote \(outputPath) from \(sourcePath)")
