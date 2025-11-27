# Parser-Scanner Compiler

קומפיילר מלא לשפת תכנות מותאמת אישית, הכולל scanner, parser, בניית AST, ניתוח סמנטי, וייצור קוד ביניים.

## תיאור הפרויקט

פרויקט זה מממש קומפיילר complete עבור שפת תכנות פרוצדורלית עם התכונות הבאות:
- **Lexical Analysis** (Scanner) - ניתוח לקסיקלי באמצעות Flex
- **Syntax Analysis** (Parser) - ניתוח תחבירי באמצעות Bison
- **Semantic Analysis** - בדיקות סמנטיות כולל type checking
- **Symbol Table** - ניהול טבלת סמלים עם תמיכה ב-scopes מקוננים
- **AST Generation** - בניית עץ תחביר מופשט
- **Three-Address Code** - ייצור קוד ביניים

## תכונות השפה

### סוגי נתונים
- `int` - מספרים שלמים (decimal, hexadecimal)
- `real` - מספרים ממשיים (עם תמיכה בייצוג מדעי)
- `char` - תווים בודדים
- `bool` - ערכי אמת (true/false, True/False)
- `string` - מחרוזות (כולל תמיכה במערכים)
- Pointers - `int*`, `real*`, `char*`

### מבני בקרה
- `if-elif-else` - תנאים
- `while` - לולאות
- `for` - לולאות ספירה
- `do` - לולאת do

### הגדרות
- `def` - הגדרת פונקציות (כולל nested functions)
- `var` - הגדרת משתנים
- `type` - הצהרת טיפוס
- `returns` - ציון טיפוס החזרה של פונקציה
- `return` - החזרת ערך מפונקציה
- `call` - קריאה לפונקציה

### אופרטורים
- **אריתמטיים**: `+`, `-`, `*`, `/`, `%`
- **השוואה**: `==`, `!=`, `<`, `>`, `<=`, `>=`
- **לוגיים**: `and`, `or`, `not`
- **השמה**: `=`
- **כתובת**: `&` (address-of)
- **אורך מערך**: `|array|`

### הערות
```
#-> זוהי הערה <-#
```

## מבנה הפרויקט

```
.
├── scanner.l              # Lexical analyzer (Flex)
├── parser.y               # Parser and semantic analyzer (Bison)
├── ast.c / ast.h          # Abstract Syntax Tree implementation
├── symbol_table.c / .h    # Symbol table with scope management
├── three_address_code.c / .h  # Intermediate code generation
├── input_test.txt         # קובץ בדיקה לדוגמה
└── README.md              # מסמך זה
```

## דרישות מערכת

- GCC (GNU Compiler Collection)
- Flex (Fast Lexical Analyzer)
- Bison (GNU Parser Generator)
- Make (אופציונלי)

## הידור והרצה

### הידור הקומפיילר

```bash
# ניקוי קבצים קודמים
rm -f parser.tab.c parser.tab.h lex.yy.c compiler

# יצירת parser
bison -d parser.y

# יצירת scanner
flex scanner.l

# הידור הקומפיילר
gcc -o compiler parser.tab.c lex.yy.c ast.c symbol_table.c three_address_code.c -lfl
```

### הרצת הקומפיילר

```bash
# הרצה עם קובץ קלט
./compiler < input_test.txt

# הרצה עם קובץ קלט אחר
./compiler < your_program.txt
```

### הידור והרצה בפקודה אחת

```bash
rm -f parser.tab.c parser.tab.h lex.yy.c compiler && \
bison -d parser.y && \
flex scanner.l && \
gcc -o compiler parser.tab.c lex.yy.c ast.c symbol_table.c three_address_code.c -lfl && \
./compiler < input_test.txt
```

## דוגמת קוד

```
def foo1(par1 int:a; par2 int:b; par3 int:c; par4 char:c1) : returns bool
var
    type bool: res;
begin
    var
        type char: x, b;
        type int: y;
    begin
      b = '&';
      a = (y*7)/a-y;
      res = (b==c) and (y>a);
    end
    return res;
end

def _main_() :
var
    type int: x1;
begin
    x1 = call foo1(1, 2, 3, 'A');
end
```

## תכונות מתקדמות

### Nested Functions
השפה תומכת בהגדרת פונקציות מקוננות בתוך פונקציות אחרות:
```
def outer(par1 int:x) :
begin
    def inner(par1 int:y) : returns int
    begin
        return x + y;
    end

    var type int: result;
    begin
        result = call inner(5);
    end
end
```

### Type Checking
הקומפיילר מבצע בדיקות טיפוסים מקיפות:
- בדיקת התאמת טיפוסים בהשמות
- בדיקת טיפוסי פרמטרים בקריאות לפונקציות
- בדיקת טיפוס ערך החזרה
- בדיקת תאימות טיפוסים בביטויים

### Scope Management
ניהול scopes היררכי עם:
- Global scope
- Function scopes
- Nested block scopes
- הסתרת משתנים (variable shadowing)

### Symbol Table
טבלת סמלים מתקדמת התומכת ב:
- הגדרות משתנים עם טיפוסים
- הגדרות פונקציות עם חתימות
- בדיקת הצהרות כפולות
- בדיקת שימוש במשתנים לא מוגדרים

## תיעוד נוסף

- `Language.pdf` - מפרט השפה
- `project-part2.pdf` - תיעוד שלב 2 (Parser)
- `project-part3.pdf` - תיעוד שלב 3 (Semantic Analysis & Code Generation)

## פלט הקומפיילר

הקומפיילר מייצר:
1. **Tokens** - פלט של ה-scanner המציג את הטוקנים שזוהו
2. **Parse Tree** - עץ ניתוח תחבירי
3. **AST** - עץ תחביר מופשט
4. **Symbol Table** - תוכן טבלת הסמלים
5. **Three-Address Code** - קוד ביניים
6. **Error Messages** - הודעות שגיאה מפורטות (לקסיקליות, תחביריות, סמנטיות)

## ניפוי באגים

להפעלת מצב debug של Bison:
```c
// בקובץ parser.y
int yydebug = 1;  // כבר מופעל בקוד
```

## שגיאות נפוצות

1. **Syntax Error** - שגיאה בתחביר התוכנית
2. **Type Mismatch** - אי-התאמת טיפוסים
3. **Undefined Variable** - שימוש במשתנה לא מוגדר
4. **Function Redeclaration** - הגדרה כפולה של פונקציה
5. **Wrong Number of Arguments** - מספר פרמטרים שגוי בקריאה לפונקציה
6. **Return Type Mismatch** - טיפוס החזרה לא תואם

## רישיון

פרויקט אקדמי - Compiler Construction Course

## יוצרים

פרויקט מימוש קומפיילר - קורס בניית מהדרים
