import 'package:test/test.dart';
import 'package:TRNIdart_analyzer/TRNIdart_analyzer.dart';
import 'test_helpers.dart';

void main() {
  MemoryFileTest mft;
  setUp(() {
    mft = new MemoryFileTest();
    mft.setUp();
  });
  test("Basic inference of method usage", () {
    var program =
    '''
    import "package:TRNIdart/TRNIdart.dart";
    
    class Bar {
      void bar(String s) {
        s.toLowerCase();
      }
    }
    ''';

    var source = mft.newSource("/test.dart", program);
    var result = mft.checkTypeForSourceWithQuery(source, "String s");
    var members = new Map();
    members["toLowerCase"] = new ArrowType([], new Bot());
    var expected = new ObjectType(members);
    expect(result, equals(expected));
  });

  test("Test of declared facet", () {
    var program =
        '''
        import "package:TRNIdart/TRNIdart.dart";
        
        class Foo {
          String bar(@declared("StringToString") String s) {
            return s;
          }
        }
        
        abstract class StringToString {
          String toString();
        }
        ''';

    var source = mft.newSource("/test.dart", program);
    var result = mft.checkTypeForSourceWithQuery(source, "bar(String s) → String");
    var members = new Map(); members["toString"] = new ArrowType([], new Bot());
    expect(result, equals(new ObjectType(members)));
  });

  test("Test of chained method call", () {
    var program =
        '''
        import "package:TRNIdart/TRNIdart.dart";
        
        class Foo {
          void foo(String s) {
            s.toLowerCase().toString().substring(0);
          }
        }
        ''';

    var source = mft.newSource("/test.dart", program);
    var result = mft.checkTypeForSourceWithQuery(source, "String s");
    var members3 = new Map(); members3["substring"] = new ArrowType([new Top()], new Bot());
    var members2 = new Map(); members2["toString"] = new ArrowType([], new ObjectType(members3));
    var members = new Map(); members["toLowerCase"] = new ArrowType([], new ObjectType(members2));
    expect(result, equals(new ObjectType(members)));
  });
}