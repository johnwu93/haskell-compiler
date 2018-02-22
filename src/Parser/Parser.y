{
module Parser.Parser where
import Data.Char

import Data.Maybe
import Data.List

import qualified Lexer.Token as T
import Parser.AST
import Parser.TerminalNode
import Parser.TerminalNodeUtil
}


%name classParser class
%name featureParser feat
%name featuresParser feats
%name expressionParser expr
%tokentype { T.Token }
%error { parseError }


%token
      int             { T.IntegerLiteral {} }
      '+'             { T.PlusOperator {} }
      '-'             { T.MinusOperator {} }
      '*'             { T.TimesOperator {} }
      '/'             { T.DivideOperator {} }
      '<'             { T.LessThanOperator {} }
      '<='            { T.LessThanOrEqualOperator {} }
      '='             { T.IsEqualsOperator {} }
      'new'           { T.NewKeyword {} }
      '('             { T.LeftParenthesesOperator {} }
      ')'             { T.RightParenthesesOperator {} }
      '{'             { T.LeftCurlyBracesOperator {} }
      '}'             { T.RightCurlyBracesOperator {} }
      ':'             { T.ColonOperator {} }
      '<-'            { T.AssignmentOperator {} }
      ';'             { T.SemicolonOperator {} }
      '~'             { T.TildeOperator {} }
      ','             { T.CommaOperator {} }
      '.'             { T.PeriodOperator {} }
      '@'             { T.AtOperator {} }
      'isvoid'        { T.IsvoidKeyword {}}
      'class'         { T.ClassKeyword {} }
      'inherits'      { T.InheritsKeyword {} }
      'not'           { T.NotKeyword {} }
      'let'           { T.LetKeyword {} }
      'in'            { T.InKeyword {} }
      'case'          { T.CaseKeyword {} }
      'of'            { T.OfKeyword {} }
      '=>'            { T.TypeBoundOperator {} }
      'esac'          { T.EsacKeyword {} }
      'if'            { T.IfKeyword {} }
      'then'          { T.ThenKeyword {} }
      'else'          { T.ElseKeyword {} }
      'fi'            { T.FiKeyword {} }
      objectID        { T.ObjectIdentifier {} }
      typeID          { T.TypeIdentifier {} }
      string          { T.StringLiteral {} }

%left '.'
%left '@'
%left '~'
%left 'isvoid'
%left '+' '-'
%left '*' '/'
%left '<=' '<' '='
%left 'not'
%right  '<-'
%%

class :: { Class }
class :
        'class' typeID '{' feats '}'    { OrphanedClass (toType $2) $4 }
      | 'class' typeID  'inherits' typeID '{' feats '}'    { InheritedClass (toType $2) (toType $4) $6 }

feats :: { [Feature] }
feats :
        {- empty -}               { [] }
      | feats feat ';'     { $1 ++ [$2] }

feat :: { Feature }
feat :
        objectID ':' typeID opt_expr     { Attribute (toIdentifier $1) (toType $3) $4 }

opt_expr :: {Maybe Expression}
opt_expr : {- empty -}            { Nothing }
         | '<-' expr              { Just $2 }

exprs :: { [Expression] }
exprs : expr ';'                  { [$1] }
      | exprs expr ';'            { $1 ++ [$2] }

letBinding :: { LetBinding }
letBinding :
             objectID ':' typeID ',' letBinding           { LetDeclaration (toIdentifier $1) (toType $3) Nothing $5 }
           | objectID ':' typeID '<-' expr ',' letBinding { LetDeclaration (toIdentifier $1) (toType $3) (Just $5) $7 }
           | objectID ':' typeID 'in' expr                { LetBinding (toIdentifier $1) (toType $3) Nothing $5 }
           | objectID ':' typeID '<-' expr 'in' expr      { LetBinding (toIdentifier $1) (toType $3) (Just $5) $7 }

caseBranch :: { CaseBranch }
caseBranch :
            objectID ':' typeID  '=>' expr ';' {CaseBranch (toIdentifier $1) (toType $3) $5 }

caseBranches :: { [CaseBranch] }
caseBranches :
                caseBranch               { [ $1 ]}
              | caseBranches caseBranch  { $1 ++ [$2] }

methodInputs :: { [Expression] }
methodInputs :
                expr                    { [ $1 ] }
              | methodInputs ',' expr   { $1 ++ [$3]}

optionalMethodInputs :: { [Expression] }
optionalMethodInputs :
              {- empty -}               { [] }
            | methodInputs              { $1 }

staticDispatch :: { Expression }
staticDispatch :
        expr '@' typeID '.'
              objectID '('
              optionalMethodInputs
              ')'                     { StaticMethodDispatch $1 (toType $3) (toIdentifier $5) $7 }
      | expr '.'
            objectID '('
            optionalMethodInputs
            ')'                       { MethodDispatch $1 (toIdentifier $3) $5 }

expr :: { Expression }
expr  :

        objectID '<-' expr      { AssignmentExpr (toIdentifier $1) $3 }
      | staticDispatch          { $1 }
      | objectID '('
        optionalMethodInputs
        ')'                     { MethodDispatch SelfVarExpr (toIdentifier $1) $3 }
      | 'if' expr 'then'
        expr 'else' expr 'fi'   { CondExpr $2 $4 $6 }
      | '{' exprs '}'           { BlockExpr $2 }
      | 'let' letBinding        { LetExpr $2 }
      | 'case' expr 'of'
         caseBranches 'esac'    { TypeCaseExpr $2 $4 }
      | 'new' typeID            { NewExpr (toType $2) }
      | 'isvoid' expr           { IsvoidExpr $2 }
      | expr '+' expr           { PlusExpr $1 $3 }
      | expr '-' expr           { MinusExpr $1 $3 }
      | expr '*' expr           { TimesExpr $1 $3 }
      | expr '/' expr           { DivideExpr $1 $3 }
      | '~' expr                { NegExpr $2 }
      | expr '<' expr           { LessThanExpr $1 $3 }
      | expr '<=' expr          { LessThanOrEqualExpr $1 $3 }
      | expr '=' expr           { EqualExpr $1 $3 }
      | 'not' expr              { NotExpr $2 }
      | '(' expr ')'            { $2 }
      | objectID                { IdentifierExpr (T.getName $1) }
      | int                     { IntegerExpr (T.getValue $1) }
      | string                  { StringExpr (T.getStrVal $1)}

{
parseError :: [T.Token] -> a
parseError tokens = error ("Parse error: Remaining Tokens " ++  (intercalate ";" (map show tokens)))

}
