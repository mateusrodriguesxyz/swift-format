//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation
import SwiftFormat
import SwiftFormatConfiguration
import SwiftFormatCore
import TSCBasic
import TSCUtility

fileprivate func main(_ arguments: [String]) -> Int32 {
  let url = URL(fileURLWithPath: arguments.first!)
  let options = processArguments(commandName: url.lastPathComponent, Array(arguments.dropFirst()))
  switch options.mode {
  case .format:
    if options.paths.isEmpty {
      let configuration = loadConfiguration(
        forSwiftFile: nil, configFilePath: options.configurationPath)
      return Int32(
        formatMain(
          configuration: configuration, sourceFile: FileHandle.standardInput,
          assumingFilename: options.assumeFilename, inPlace: false,
          debugOptions: options.debugOptions))
    }
    return processSources(from: options.paths, configurationPath: options.configurationPath) {
      (sourceFile, path, configuration) in
      formatMain(
        configuration: configuration, sourceFile: sourceFile, assumingFilename: path,
        inPlace: options.inPlace, debugOptions: options.debugOptions)
    }
  case .lint:
    if options.paths.isEmpty {
      let configuration = loadConfiguration(
        forSwiftFile: nil, configFilePath: options.configurationPath)
      return Int32(
        lintMain(
          configuration: configuration, sourceFile: FileHandle.standardInput,
          assumingFilename: options.assumeFilename, debugOptions: options.debugOptions))
    }
    return processSources(from: options.paths, configurationPath: options.configurationPath) {
      (sourceFile, path, configuration) in
      lintMain(
        configuration: configuration, sourceFile: sourceFile, assumingFilename: path,
        debugOptions: options.debugOptions)
    }
  case .dumpConfiguration:
    dumpDefaultConfiguration()
    return 0
  case .version:
    print("0.0.1")  // TODO: Automate updates to this somehow.
    return 0
  }
}

/// Processes the source code at the given file paths by performing a transformation, provided by a
/// closure.
/// - Parameters:
///   - paths: The file paths for the source files to process with a transformation.
///   - configurationPath: The file path to a swift-format configuration file.
///   - transform: A closure that performs a transformation on a specific source file.
fileprivate func processSources(
  from paths: [String], configurationPath: String?,
  transform: (FileHandle, String, Configuration) -> Int
) -> Int32 {
  var result = 0
  for path in FileIterator(paths: paths) {
    guard let sourceFile = FileHandle(forReadingAtPath: path) else {
      stderrStream.write("Unable to create a file handle for source from \(path).\n")
      stderrStream.flush()
      return 1
    }
    let configuration = loadConfiguration(forSwiftFile: path, configFilePath: configurationPath)
    result |= transform(sourceFile, path, configuration)
  }
  return Int32(result)
}

/// Load the configuration.
fileprivate func loadConfiguration(
  forSwiftFile swiftFilePath: String?, configFilePath: String?
) -> Configuration {
  if let path = configFilePath {
    return decodedConfiguration(fromFile: URL(fileURLWithPath: path))
  }

  if let swiftFileUrl = swiftFilePath.map(URL.init(fileURLWithPath:)), 
    let configFileUrl = Configuration.configurationFile(forSwiftFile: swiftFileUrl) {
      return decodedConfiguration(fromFile: configFileUrl)
  }

  return Configuration()
}


/// Loads and returns a `Configuration` from the given JSON file if it is found and is valid. If the
/// file does not exist or there was an error decoding it, the program exits with a non-zero exit
/// code.
fileprivate func decodedConfiguration(fromFile url: Foundation.URL) -> Configuration {
  do {
    return try Configuration(configFile: url)
  } catch {
    // TODO: Improve error message, write to stderr.
    print("Could not load configuration at \(url): \(error)")
    exit(1)
  }
}

/// Dumps the default configuration as JSON to standard output.
fileprivate func dumpDefaultConfiguration() {
  let configuration = Configuration()
  do {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted]
    if #available(macOS 10.13, *) {
      encoder.outputFormatting.insert(.sortedKeys)
    }

    let data = try encoder.encode(configuration)
    guard let jsonString = String(data: data, encoding: .utf8) else {
      // This should never happen, but let's make sure we fail more gracefully than crashing, just
      // in case.
      // TODO: Improve error message, write to stderr.
      print("Could not dump the default configuration: the JSON was not valid UTF-8")
      exit(1)
    }
    print(jsonString)
  } catch {
    // TODO: Improve error message, write to stderr.
    print("Could not dump the default configuration: \(error)")
    exit(1)
  }
}

exit(main(CommandLine.arguments))
