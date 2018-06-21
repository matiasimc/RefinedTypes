import 'package:test/test.dart';
import 'package:TRNIdart_analyzer/TRNIdart_analyzer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/generated/engine.dart' hide Logger;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/file_system.dart' hide File;
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:analyzer/source/package_map_resolver.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/task/dart.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/dart/sdk/sdk.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/source/source_resource.dart';
import 'package:cli_util/cli_util.dart' show getSdkPath;
import 'package:TRNIdart_analyzer/analyzer.dart';

class MemoryFileTest {
  MemoryResourceProvider resourceProvider = new MemoryResourceProvider();
  DartSdk sdk;
  AnalysisContext context;

  Source newSource(String path, [String content = '']) {
    final file = resourceProvider.newFile(path, content);
    final source = file.createSource();
    return source;
  }

  void addSource(Source source) {
    ChangeSet changeSet = new ChangeSet()..addedSource(source);
    context.applyChanges(changeSet);
  }

  DartSdk getDartSdk() {
    PhysicalResourceProvider physicalResourceProvider = PhysicalResourceProvider.INSTANCE;
    var dartSdkDirectory = getSdkPath();
    DartSdk sdk = new FolderBasedDartSdk(
        physicalResourceProvider, physicalResourceProvider.getFolder(dartSdkDirectory));
    return sdk;
  }

  void setUp() {
    sdk = getDartSdk();

    context = AnalysisEngine.instance.createAnalysisContext();

    final packageMap = <String, List<Folder>>{
      "TRNIdart": [resourceProvider.getFolder("/TRNIdart")]
    };
    final packageResolver =
    new PackageMapUriResolver(resourceProvider, packageMap);

    final sf = new SourceFactory([
      new DartUriResolver(sdk),
      packageResolver,
      new ResourceUriResolver(resourceProvider)
    ]);

    context.sourceFactory = sf;

    var secDart = newSource("/TRNIDart/TRNIDart.dart", _getTRNIDartContent());

    Source source = secDart;
    ChangeSet changeSet = new ChangeSet()..addedSource(source);
    context.applyChanges(changeSet);
    TRNIAnalyzer.reset();
  }

  String _getTRNIDartContent() {
    return
        '''
/**
Represent the declared interface of a public facet
 */
class declared {
  const declared(String s);
}

/**
    Represent the inferred interface of a public facet
 */
class inferred {
  const inferred(String s);
}
        ''';
  }

  IType checkTypeForSourceWithQuery(Source original, String query) {
    var resolvedUnit = context.resolveCompilationUnit(original, context.computeLibraryElement(original));
    TRNIAnalyzer.computeConstraints(resolvedUnit);
    TRNIAnalyzer.computeTypes();
    Element element = TRNIAnalyzer.store.elements.keys.firstWhere((e) => e.toString() == query);
    if (element == null) return null;
    return TRNIAnalyzer.store.getType(element);
  }

}