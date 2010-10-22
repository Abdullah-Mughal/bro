// parse.y - parser for flex input

%{
// $Id: re-parse.y 5857 2008-06-26 23:00:03Z vern $

#include <stdlib.h>

#include "CCL.h"
#include "NFA.h"
#include "EquivClass.h"

int csize = 256;
int syntax_error = 0;

int reverse_case(int sym);
void yyerror(const char msg[]);
%}

%token TOK_CHAR TOK_NUMBER TOK_CCL TOK_CCE

%union {
	int int_val;
	cce_func cce_val;
	CCL* ccl_val;
	NFA_Machine* mach_val;
}

%type <int_val> TOK_CHAR TOK_NUMBER
%type <cce_val> TOK_CCE
%type <ccl_val> TOK_CCL ccl full_ccl
%type <mach_val> re singleton series string

%%
flexrule	:	re
			{ $1->AddAccept(1); nfa = $1; }

		|  error
			{ return 1; }
		;

re		:  re '|' series
			{ $$ = make_alternate($1, $3); }
		|  series
		| 
			{ $$ = new NFA_Machine(new EpsilonState()); }
		;

series		:  series singleton
			{ $1->AppendMachine($2); }
		|  singleton
		;

singleton	:  singleton '*'
			{ $1->MakeClosure(); }

		|  singleton '+'
			{ $1->MakePositiveClosure(); }

		|  singleton '?'
			{ $1->MakeOptional(); }

		|  singleton '{' TOK_NUMBER ',' TOK_NUMBER '}'
			{
			if ( $3 > $5 || $3 < 0 )
				synerr("bad iteration values");
			else
				{
				if ( $3 == 0 )
					{
					if ( $5 == 0 )
						{
						$$ = new NFA_Machine(new EpsilonState());
						Unref($1);
						}
					else
						{
						$1->MakeRepl(1, $5);
						$1->MakeOptional();
						}
					}
				else
					$1->MakeRepl($3, $5);
				}
			}

		|  singleton '{' TOK_NUMBER ',' '}'
			{
			if ( $3 < 0 )
				synerr("iteration value must be positive");
			else if ( $3 == 0 )
				$1->MakeClosure();
			else
				$1->MakeRepl($3, NO_UPPER_BOUND);
			}

		|  singleton '{' TOK_NUMBER '}'
			{
			if ( $3 < 0 )
				synerr("iteration value must be positive");
			else if ( $3 == 0 )
				{
				Unref($1);
				$$ = new NFA_Machine(new EpsilonState());
				}
			else
				$1->LinkCopies($3-1);
			}

		|  '.'
			{
			$$ = new NFA_Machine(new NFA_State(rem->AnyCCL()));
			}

		|  full_ccl
			{
			$1->Sort();
			rem->EC()->CCL_Use($1);
			$$ = new NFA_Machine(new NFA_State($1));
			}

		|  TOK_CCL
			{ $$ = new NFA_Machine(new NFA_State($1)); }

		|  '"' string '"'
			{ $$ = $2; }

		|  '(' re ')'
			{ $$ = $2; }

		|  TOK_CHAR
			{
			if ( rem->CaseInsensitive() )
				{
				$$ = make_alternate(new NFA_Machine(new NFA_State($1, rem->EC())),
				                    new NFA_Machine(new NFA_State(reverse_case($1), rem->EC())));
				}
			else
				$$ = new NFA_Machine(new NFA_State($1, rem->EC()));
			}

		|  '^'
			{
			$$ = new NFA_Machine(new NFA_State(SYM_BOL, rem->EC()));
			$$->MarkBOL();
			}

		|  '$'
			{
			$$ = new NFA_Machine(new NFA_State(SYM_EOL, rem->EC()));
			$$->MarkEOL();
			}
		;

full_ccl	:  '[' ccl ']'
			{ $$ = $2; }

		|  '[' '^' ccl ']'
			{
			$3->Negate();
			$$ = $3;
			}
		;

ccl		:  ccl TOK_CHAR '-' TOK_CHAR
			{
			if ( $2 > $4 )
				synerr("negative range in character class");

			else
				{
				for ( int i = $2; i <= $4; ++i )
					$1->Add(i);
					
				if ( rem->CaseInsensitive() )
					{
					$2 = reverse_case($2);
					$4 = reverse_case($4);
					for ( int i = $2; i <= $4; ++i )
						$1->Add(i);
					}
				}
			$$=$1;
			}

		|  ccl TOK_CHAR
			{
			$1->Add($2);
			if ( rem->CaseInsensitive() )
				{
				$2 = reverse_case($2);
				$1->Add($2);
				}
			$$=$1;
			}

		|  ccl ccl_expr

		|
			{ $$ = curr_ccl; }
		;

ccl_expr:	   TOK_CCE
			{
			for ( int c = 0; c < csize; ++c )
				if ( isascii(c) && $1(c) )
					curr_ccl->Add(c);
			}
		;

string		:  string TOK_CHAR
			{
			if ( rem->CaseInsensitive() )
				$$ = make_alternate(new NFA_Machine(new NFA_State($2, rem->EC())),
			                        new NFA_Machine(new NFA_State(reverse_case($2), rem->EC())));
			else
				$$ = new NFA_Machine(new NFA_State($2, rem->EC()));

			$1->AppendMachine($$);
			}

		|
			{ $$ = new NFA_Machine(new EpsilonState()); }
		;
%%

int reverse_case(int sym)
{
	return isupper (sym) ? tolower (sym) : (islower (sym) ? toupper (sym) : sym);
}

void synerr(const char str[])
	{
	syntax_error = true;
	run_time("%s (compiling pattern /%s/)", str, RE_parse_input);
	}

void yyerror(const char msg[])
	{
	}
