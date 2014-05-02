describe 'Go grammar', ->
  grammar = null

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-go')

    runs ->
      grammar = atom.syntax.grammarForScopeName('source.go')

  it 'parses the grammar', ->
    expect(grammar).toBeTruthy()
    expect(grammar.scopeName).toBe 'source.go'

  it 'tokenizes comments', ->
    {tokens} = grammar.tokenizeLine('// I am a comment')
    expect(tokens[0].value).toEqual '//'
    expect(tokens[0].scopes).toEqual ['source.go', 'comment.line.double-slash.go', 'punctuation.definition.comment.go']
    expect(tokens[1].value).toEqual ' I am a comment'
    expect(tokens[1].scopes).toEqual ['source.go', 'comment.line.double-slash.go']

    tokens = grammar.tokenizeLines('/*\nI am a comment\n*/')
    expect(tokens[0][0].value).toEqual '/*'
    expect(tokens[0][0].scopes).toEqual ['source.go', 'comment.block.go', 'punctuation.definition.comment.go']
    expect(tokens[1][0].value).toEqual 'I am a comment'
    expect(tokens[1][0].scopes).toEqual ['source.go', 'comment.block.go']
    expect(tokens[2][0].value).toEqual '*/'
    expect(tokens[2][0].scopes).toEqual ['source.go', 'comment.block.go', 'punctuation.definition.comment.go']

  it 'tokenizes strings', ->
    delims =
      'string.quoted.double.go': '"'
      'string.quoted.single.go': '\''
      'string.quoted.double.raw.backtick.go': '`'

    for scope, delim of delims
      {tokens} = grammar.tokenizeLine(delim + 'I am a string' + delim)
      expect(tokens[0].value).toEqual delim
      expect(tokens[0].scopes).toEqual ['source.go', scope, 'punctuation.definition.string.begin.go']
      expect(tokens[1].value).toEqual 'I am a string'
      expect(tokens[1].scopes).toEqual ['source.go', scope]
      expect(tokens[2].value).toEqual delim
      expect(tokens[2].scopes).toEqual ['source.go', scope, 'punctuation.definition.string.end.go']

  it 'tokenizes Printf verbs in strings', ->
    # Taken from go/src/pkg/fmt/fmt_test.go
    verbs = [
      '%# x', '%-5s', '%5s', '%05s', '%.5s', '%10.1q', '%10v', '%-10v', '%.0d'
      '%.d', '%+07.2f', '%0100d', '%0.100f', '%#064x', '%+.3F', '%-#20.8x',
      '%[1]d', '%[2]*[1]d', '%[3]*.[2]*[1]f', '%[3]*.[2]f', '%3.[2]d', '%.[2]d'
      '%-+[1]x', '%d', '%-d', '%+d', '%#d', '% d', '%0d', '%1.2d', '%-1.2d'
      '%+1.2d', '%-+1.2d', '%*d', '%.*d', '%*.*d', '%0*d', '%-*d'
    ]

    for verb in verbs
      {tokens} = grammar.tokenizeLine('"' + verb + '"')
      expect(tokens[0].value).toEqual '"',
      expect(tokens[0].scopes).toEqual ['source.go', 'string.quoted.double.go', 'punctuation.definition.string.begin.go']
      expect(tokens[1].value).toEqual verb
      expect(tokens[1].scopes).toEqual ['source.go', 'string.quoted.double.go', 'constant.escape.format-verb.go']
      expect(tokens[2].value).toEqual '"',
      expect(tokens[2].scopes).toEqual ['source.go', 'string.quoted.double.go', 'punctuation.definition.string.end.go']

  it 'tokenizes character escapes in strings', ->
    escapes = [
      '\\a', '\\b', '\\f', '\\n', '\\r', '\\t', '\\v', '\\\\'
      '\\000', '\\007', '\\377', '\\x07', '\\xff', '\\u12e4', '\\U00101234'
    ]

    for escape in escapes
      {tokens} = grammar.tokenizeLine('"' + escape + '"')
      expect(tokens[1].value).toEqual escape
      expect(tokens[1].scopes).toEqual ['source.go', 'string.quoted.double.go', 'constant.character.escape.go']

    {tokens} = grammar.tokenizeLine('"\\""')
    expect(tokens[1].value).toEqual '\\"'
    expect(tokens[1].scopes).toEqual ['source.go', 'string.quoted.double.go', 'constant.character.escape.go']

    {tokens} = grammar.tokenizeLine('\'\\\'\'')
    expect(tokens[1].value).toEqual '\\\'',
    expect(tokens[1].scopes).toEqual ['source.go', 'string.quoted.single.go', 'constant.character.escape.go']

  it 'tokenizes invalid whitespace around chan annotations', ->
    invalids =
      'chan <- sendonly': ' '
      '<- chan recvonly': ' '
      'trailingspace   ': '   '
      'trailingtab\t': '\t'

    for expr, invalid of invalids
      {tokens} = grammar.tokenizeLine(expr)
      expect(tokens[1].value).toEqual invalid
      expect(tokens[1].scopes).toEqual ['source.go', 'invalid.illegal.go']

  it 'tokenizes keywords', ->
    keywordLists =
      'keyword.go': ['var', 'const', 'type', 'struct', 'interface', 'case', 'default']
      'keyword.directive.go': ['package', 'import']
      'keyword.statement.go': ['defer', 'go', 'goto', 'return', 'break', 'continue', 'fallthrough']
      'keyword.conditional.go': ['if', 'else', 'switch', 'select']
      'keyword.repeat.go': ['for', 'range']

    for scope, list of keywordLists
      for keyword in list
        {tokens} = grammar.tokenizeLine keyword
        expect(tokens[0].value).toEqual keyword
        expect(tokens[0].scopes).toEqual ['source.go', scope]

  it 'tokenizes types', ->
    types = [
      'chan',   'map',     'bool',    'string',  'error',     'int',        'int8',   'int16'
      'int32',  'int64',   'rune',    'byte',    'uint',      'uint8',      'uint16', 'uint32'
      'uint64', 'uintptr', 'float32', 'float64', 'complex64', 'complex128'
    ]

    for type in types
      {tokens} = grammar.tokenizeLine type
      expect(tokens[0].value).toEqual type
      expect(tokens[0].scopes).toEqual ['source.go', 'storage.type.go']

  it 'tokenizes "func" as a keyword or type based on context', ->
    funcKeyword = ['func f()', 'func (x) f()', 'func(x) f()', 'func']
    for line in funcKeyword
      {tokens} = grammar.tokenizeLine line
      expect(tokens[0].value).toEqual 'func'
      expect(tokens[0].scopes).toEqual ['source.go', 'keyword.go']

    funcType = [
      {
        'line': 'var f1 func('
        'tokenPos': 4
      }
      {
        'line': 'f2 :=func()'
        'tokenPos': 3
      }
      {
        'line': '\tfunc('
        'tokenPos': 1
      }
      {
        'line': 'type HandlerFunc func('
        'tokenPos': 4
      }
    ]
    for t in funcType
      {tokens} = grammar.tokenizeLine t.line

      relevantToken = tokens[t.tokenPos]
      expect(relevantToken.value).toEqual 'func'
      expect(relevantToken.scopes).toEqual ['source.go', 'storage.type.go']

      next = tokens[t.tokenPos + 1]
      expect(next.value).toEqual '('
      expect(next.scopes).toEqual ['source.go', 'keyword.operator.go']

  it 'tokenizes func names in their declarations', ->
    tests = [
      {
        'line': 'func f()'
        'tokenPos': 2
      }
      {
        'line': 'func (T) f()'
        'tokenPos': 2
      }
      {
        'line': 'func (t T) f()'
        'tokenPos': 2
      }
      {
        'line': 'func (t *T) f()'
        'tokenPos': 2
      }
    ]

    for t in tests
      {tokens} = grammar.tokenizeLine t.line
      expect(tokens[0].value).toEqual 'func'
      expect(tokens[0].scopes).toEqual ['source.go', 'keyword.go']

      relevantToken = tokens[t.tokenPos]
      expect(relevantToken).toBeDefined()
      expect(relevantToken.value).toEqual 'f'
      expect(relevantToken.scopes).toEqual ['source.go', 'support.function.go']

      next = tokens[t.tokenPos + 1]
      expect(next.value).toEqual '('
      expect(next.scopes).toEqual ['source.go', 'keyword.operator.go']

  it 'tokenizes numerics', ->
    numerics = [
      '42', '0600', '0xBadFace', '170141183460469231731687303715884105727', '0.', '72.40'
      '072.40', '2.71828', '1.e+0', '6.67428e-11', '1E6', '.25', '.12345E+5', '0i', '011i'
      '0.i', '2.71828i', '1.e+0i', '6.67428e-11i', '1E6i', '.25i', '.12345E+5i'
    ]

    for num in numerics
      {tokens} = grammar.tokenizeLine num
      expect(tokens[0].value).toEqual num
      expect(tokens[0].scopes).toEqual ['source.go', 'constant.numeric.go']

    invalidOctals = ['08', '039', '0995']
    for num in invalidOctals
      {tokens} = grammar.tokenizeLine num
      expect(tokens[0].value).toEqual num
      expect(tokens[0].scopes).toEqual ['source.go', 'invalid.illegal.numeric.go']

  it 'tokenizes language constants', ->
    constants = ['iota', 'true', 'false', 'nil']
    for constant in constants
      {tokens} = grammar.tokenizeLine constant
      expect(tokens[0].value).toEqual constant
      expect(tokens[0].scopes).toEqual ['source.go', 'constant.language.go']

  it 'tokenizes built-in functions', ->
    funcs = [
      'append', 'cap', 'close', 'complex', 'copy', 'delete', 'imag', 'len', 'make', 'new',
      'panic', 'print', 'println', 'real', 'recover'
    ]

    for func in funcs
      {tokens} = grammar.tokenizeLine func
      expect(tokens[0].value).toEqual func
      expect(tokens[0].scopes).toEqual ['source.go', 'support.function.built-in.go']

  it 'tokenizes operators', ->
    opers = [
      '+', '&', '+=', '&=', '&&', '==', '!=', '(', ')', '-', '|', '-=', '|=', '||', '<',
      '<=', '[', ']', '*', '^', '*=', '^=', '<-', '>', '>=', '{', '}', '/', '<<', '/=',
      '<<=', '++', '=', ':=', ',', ';', '%', '>>', '%=', '>>=', '--', '!', '...', '.',
      ':', '&^', '&^='
    ]

    for op in opers
      {tokens} = grammar.tokenizeLine op

      fullOp = tokens.map((tok) -> tok.value).join('')
      expect(fullOp).toEqual op

      scopes = tokens.map (tok) -> tok.scopes
      allKeywords = scopes.every (scope) -> 'keyword.operator.go' in scope

      expect(allKeywords).toBe true

  it 'tokenizes func names in calls to them', ->
    tests = [
      {
        'line': 'a.b()'
        'name': 'b'
        'tokenPos': 2
        'isFunc': true
      }
      {
        'line': 'pkg.Func1('
        'name': 'Func1'
        'tokenPos': 2
        'isFunc': true
      }
      {
        'line': 'pkg.Func1().Func2('
        'name': 'Func2'
        'tokenPos': 6
        'isFunc': true
      }
      {
        'line': 'pkg.var'
        'name': 'var'
        'tokenPos': 2
        'isFunc': false
      }
      {
        'line': 'doWork(ch)'
        'name': 'doWork'
        'tokenPos': 0
        'isFunc': true
      }
      {
        'line': 'f1()'
        'name': 'f1'
        'tokenPos': 0
        'isFunc': true
      }
    ]

    want = ['source.go', 'support.function.go']

    for t in tests
      {tokens} = grammar.tokenizeLine t.line

      relevantToken = tokens[t.tokenPos]
      if t.isFunc
        expect(relevantToken).not.toBeNull()
        expect(relevantToken.value).toEqual t.name
        expect(relevantToken.scopes).toEqual want

        next = tokens[t.tokenPos + 1]
        expect(next.value).toEqual '('
        expect(next.scopes).toEqual ['source.go', 'keyword.operator.go']
      else
        expect(relevantToken.scopes).not.toEqual want

  it 'tokenizes type names in their declarations', ->
    {tokens} = grammar.tokenizeLine 'type Stringer interface {'
    expect(tokens[0].value).toBe 'type'
    expect(tokens[0].scopes).toEqual ['source.go', 'keyword.go']
    expect(tokens[2].value).toBe 'Stringer'
    expect(tokens[2].scopes).toEqual ['source.go', 'storage.type.go']

    {tokens} = grammar.tokenizeLine 'type Duration int64'
    expect(tokens[0].value).toBe 'type'
    expect(tokens[0].scopes).toEqual ['source.go', 'keyword.go']
    expect(tokens[2].value).toBe 'Duration'
    expect(tokens[2].scopes).toEqual ['source.go', 'storage.type.go']

    {tokens} = grammar.tokenizeLine 'type   byLength []string'
    expect(tokens[0].value).toBe 'type'
    expect(tokens[0].scopes).toEqual ['source.go', 'keyword.go']
    expect(tokens[2].value).toBe 'byLength'
    expect(tokens[2].scopes).toEqual ['source.go', 'storage.type.go']

    {tokens} = grammar.tokenizeLine '  type T'
    expect(tokens[2].value).toBe ' T'
    expect(tokens[2].scopes).not.toEqual ['source.go', 'storage.type.go']

  # TODO: finish adding tests from the spec (golang.org/ref/spec#VarDecl)
  describe 'in variable declarations', ->
    testVar = (token) ->
      expect(token.value).toBe 'var'
      expect(token.scopes).toEqual ['source.go', 'keyword.go']

    wantedScope = ['source.go', 'variable.go']

    # var i int
    # var U, V, W float64
    # var k = 0
    # var x, y float32 = -1, -2
    # var (
    #     i       int
    #     u, v, s = 2.0, 3.0, "bar"
    # )
    # var re, im = complexSqrt(-1)
    # var _, found = entries[name]
    describe 'in "var" statements', ->
      it 'tokenizes single names', ->
        {tokens} = grammar.tokenizeLine 'var vardecl1  = "this is going to be rough!"'
        testVar tokens[0]
        expect(tokens[2].value).toBe 'vardecl1'
        expect(tokens[2].scopes).toEqual wantedScope

        {tokens} = grammar.tokenizeLine '     var  vardecl2 string'
        testVar tokens[1]
        expect(tokens[3].value).toBe 'vardecl2'
        expect(tokens[3].scopes).toEqual wantedScope

      xit 'tokenizes multiple names', ->
        {tokens} = grammar.tokenizeLine '     var  a, b = 3, 4'
        testVar tokens[1]
        expect(tokens[3].value).toBe 'a'
        expect(tokens[3].scopes).toEqual wantedScope
        expect(tokens[6].value).toBe 'b'
        expect(tokens[6].scopes).toEqual wantedScope

        {tokens} = grammar.tokenizeLine 'var x, y int'
        testVar tokens[0]
        expect(tokens[2].value).toBe 'x'
        expect(tokens[2].scopes).toEqual wantedScope
        expect(tokens[5].value).toBe 'y'
        expect(tokens[5].scopes).toEqual wantedScope

      xdescribe 'in "var" statement blocks', ->
        it 'tokenizes single names', ->
          [kwd, decl, _] = grammar.tokenizeLines '\tvar (\n\t\tfoo *bar\n\t)'
          testVar kwd[1]
          expect(decl[1].value).toBe 'foo'
          expect(decl[1].scopes).toEqual wantedScope

        it 'tokenizes multiple names', ->
          [kwd, _, decl, _] = grammar.tokenizeLines 'var (\n\n\tfoo, bar = baz, quux\n)'
          testVar kwd[0]
          expect(decl[1].value).toBe 'foo'
          expect(decl[1].scopes).toEqual wantedScope
          expect(decl[4].value).toBe 'bar'
          expect(decl[4].scopes).toEqual wantedScope

      # i, j := 0, 10
      # ch := make(chan int)
      # r, w := os.Pipe(fd)
      # _, y, _ := coord(p)
      describe 'in shorthand variable declarations', ->
        it 'tokenizes single names', ->
          {tokens} = grammar.tokenizeLine 'f := func() int { return 7 }'
          expect(tokens[0].value).toBe 'f'
          expect(tokens[0].scopes).toEqual ['source.go', 'variable.go']
          expect(tokens[2].value).toBe ':='
          expect(tokens[2].scopes).toEqual ['source.go', 'keyword.operator.go']

        xit 'tokenizes multiple names', ->

