grammar luna;

// TOKENS

WHITESPACE
    : [ \t\n\r]+ -> skip
    ;

NUMBER
    : [0-9]+
    ;

STRING
    : '"'  ~'"'*  '"'
    | '\'' ~'\''* '\''
    ;

IDENTIFIER
    : [a-zA-Z_][a-zA-Z_0-9]*
    ;

// TOP RULE

program
    : statement* EOF
    ;

// STATEMENTS

statement
    : variable_declaration
    | function_declaration
    | block_statement
    | if_statement
    | for_statement
    | while_statement
    | switch_statement
    | break_statement
    | continue_statement
    | goto_statement
    | labeled_statement
    | return_statement
    | expression_statement
    ;

variable_declaration
    : 'let' IDENTIFIER ( '=' expression )?
    ;

function_declaration
    : 'def' IDENTIFIER '(' arguments? ')' block_statement
    ;

if_statement
    : 'if' '(' expression ')' statement ('else' statement)?
    ;

for_statement
    : 'for' '(' expression ')' statement // TODO: unfinished
    ;

while_statement
    : 'while' '(' expression ')' statement
    ;

switch_statement
    : 'switch' '(' expression ')' '{' cases '}'
    ;

cases
    : case (',' case)*
    ;

case
    : expression '->' statement
    ;

break_statement
    : 'break'
    ;

continue_statement
    : 'continue'
    ;

goto_statement
    : 'goto' IDENTIFIER
    ;

labeled_statement
    : IDENTIFIER':' statement
    ;

return_statement
    : 'return' expression?
    ;

block_statement
    : '{' statement* '}'
    ;

expression_statement
    : expression
    ;

// EXPRESSIONS

expression
    : assignment_expression
    ;

assignment_expression
    : prefix_expression '=' assignment_expression
    | logical_or_expression
    ;

logical_or_expression
    : logical_and_expression
    | logical_or_expression '||' logical_and_expression
    ;

logical_and_expression
    : equality_expression
    | logical_and_expression '&&' equality_expression
    ;

equality_expression
    : relational_expression
    | equality_expression ( '==' | '!=' ) relational_expression
    ;

relational_expression
    : concatenative_expression
    | relational_expression ( '<' | '<=' | '>' | '>=' ) concatenative_expression
    ;

concatenative_expression
    : additive_expression
    | concatenative_expression '..' additive_expression
    ;

additive_expression
    : multiplicative_expression
    | additive_expression '+' multiplicative_expression
    ;

multiplicative_expression
    : power_expression
    | multiplicative_expression ( '*' | '/' ) power_expression
    ;

power_expression
    : prefix_expression ( '**'  power_expression )*
    ;

prefix_expression
    : ( '!' | '-' | '+' )* postfix_expression
    ;

postfix_expression
    : primary_expression ( call_expression | index_expression | access_expression )*
    ;

call_expression
    : '(' arguments? ')'
    ;

index_expression
    : '[' expression ']'
    ;

access_expression
    : '.' IDENTIFIER
    ;

primary_expression
    : grouping_expression
    | literal_expression
    ;

grouping_expression
    : '(' expression ')'
    ;

literal_expression
    : 'null'
    | 'true'
    | 'false'
    | NUMBER
    | STRING
    | IDENTIFIER
    | array_expression
    | table_expression
    | lambda_expression
    ;

array_expression
    : '[' arguments? ']'
    ;

table_expression
    : '{' fields? '}'
    ;

lambda_expression
    : 'def' '(' parameters? ')' statement
    ;

parameters
    : IDENTIFIER ( ',' IDENTIFIER )*
    ;

arguments
    : expression ( ',' expression )*
    ;

fields
    : field ( ',' field )*
    ;

field
    : expression ':' expression
    ;
