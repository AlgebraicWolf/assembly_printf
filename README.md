# Simple printf implementation
This is simple implementation of printf function that accepts arguments via stack. Here are supported format specifiers:
+ `%%` &ndash; Percent symbol
+ `%d` &ndash; Signed decimal 32-bit integer
+ `%o` &ndash; Unsigned octal 32-bit integer
+ `%u` &ndash; Unsigned decimal 32-bit integer
+ `%x` &ndash; Unsigned hexadecimal integer
+ `%c` &ndash; Character
+ `%s` &ndash; Null-terminated string 
+ `%p` &ndash; Pointer
`invoke` macro that allows to call function easily is provided as well.
