/* parse-english
 * -- A minimum viable English parser implemented in LexYacc
 * Copyright (C) 2011 onlyuser <mailto:onlyuser@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

%option outfile="lex.parse-english.c"

%{

#include "parse-english.h"
#include "node/XLangNodeIFace.h" // node::NodeIdentIFace
#include "parse-englishLexerIDWrapper.h" // ID_XXX (yacc generated)
#include "XLangString.h" // xl::unescape
#include <string.h> // memcpy
#include <stdlib.h> // atoi
#include <algorithm> // std::min
#include <iostream> // std::cout

// When in the lexer you have to access parm through the extra data.
#define PARM yyget_extra(yyscanner)->scanner_context()

// We want to read from a the buffer in parm so we have to redefine the
// YY_INPUT macro (see section 10 of the flex manual 'The generated scanner')
#define YY_INPUT(buf, result, max_size) \
    do { \
        if(PARM.m_pos >= PARM.m_length || (max_size) < 1) { \
            (result) = YY_NULL; \
            break; \
        } else { \
            if('\n' == PARM.m_buf[PARM.m_pos]) { \
                PARM.m_line++; \
                PARM.m_column = 1; \
            } else { \
                PARM.m_column++; \
            } \
            (buf)[0] = PARM.m_buf[PARM.m_pos]; \
            PARM.m_pos++; \
            (result) = 1; \
        } \
    } while(0)

#define LOC             begin_token(yyscanner, yyleng);
#define PUSH_STATE(x)   yy_push_state(x, yyscanner)
#define POP_STATE       yy_pop_state(yyscanner)
#define LVAL            (*yylval)
#define TREE_CONTEXT    yyget_extra(yyscanner)->tree_context()
#define SCANNER_CONTEXT yyget_extra(yyscanner)->scanner_context()

void begin_token(yyscan_t yyscanner, size_t length);

%}

%option noyywrap nounput noyy_top_state
%option reentrant bison-bridge bison-locations
%option stack
%x ST_COMMENT_BLOCK ST_COMMENT_LINE ST_ORIG_WORD

ws        [ \t\n]+
any       .|[\n]
lit_char  [.,?!]
digit     [0-9]
alpha     [a-zA-Z]
id        {alpha}|[_]|[,]
lit_ident {id}+({digit}|{id})*
lit_int   {digit}+
lit_float {digit}*[.]{digit}+
consonant [^aeiou]

noun_singular_people    "person"|"man"|"woman"|"boy"|"girl"|"child"|"baby"|"teacher"|"student"|"worker"
noun_singular_place     "place"|"house"|"home"|"park"|"school"|"library"|"store"|"theater"|"museum"|"hospital"|"lake"|"ocean"|"mountain"|"valley"
noun_singular_vehicle   "car"|"bicycle"|"motorcycle"|"train"|"airplane"
noun_singular_animal    "fox"|"dog"|"cat"|"bird"|"fish"|"cow"|"pig"|"horse"|"chicken"|"sheep"|"crow"|"pigeon"|"mouse"
noun_singular_misc      "building"|"bridge"|"tunnel"
noun_singular           {noun_singular_people}|{noun_singular_place}|{noun_singular_vehicle}|{noun_singular_animal}|{noun_singular_misc}
noun_plural_people      "people"|"men"|"women"|"boys"|"girls"|"children"|"babies"|"teachers"|"students"|"workers"
noun_plural_place       "places"|"houses"|"parks"|"schools"|"libraries"|"stores"|"theaters"|"museums"|"hospitals"|"lakes"|"oceans"|"mountains"|"valleys"
noun_plural_vehicle     "cars"|"bicycles"|"motorcycles"|"trains"|"airplanes"
noun_plural_animal      "foxes"|"dogs"|"cats"|"birds"|"NOUN_PLURAL(fish)"|"cows"|"pigs"|"horses"|"NOUN_PLURAL(chicken)"|"NOUN_PLURAL(sheep)"|"crows"|"pigeons"|"mice"
noun_plural_misc        "buildings"|"bridges"|"tunnels"
noun_plural             {noun_plural_people}|{noun_plural_place}|{noun_plural_vehicle}|{noun_plural_animal}|{noun_plural_misc}
noun                    {noun_singular}|{noun_plural}

pronoun_people          "i"|"you"|"he"|"she"|"it"|"they"|"them"|"him"|"her"|"we"|"us"|"me"|"everyone"|"someone"|"one"
pronoun_place           "here"|"there"|"somewhere"|"anywhere"
pronoun_things          "something"|"nothing"|"anything"|"everything"|"thing"|"things"
pronoun                 {pronoun_people}|{pronoun_place}|{pronoun_things}

verb_locomotion         "V(do)"|"V(does)"|"V(come)"|"comes"|"go"|"goes"|"walk"|"walks"|"V(run)"|"runs"|"jump"|"jumps"|"swim"|"swims"|"crawl"|"crawls"|"fly"|"flies"|"ride"|"rides"|"eat"|"eats"
verb_transaction        "V(put)"|"puts"|"get"|"gets"|"give"|"gives"|"take"|"takes"|"lend"|"lends"|"buy"|"buys"|"sell"|"sells"
verb_communication      "tell"|"tells"|"say"|"says"|"speak"|"speaks"|"hear"|"hears"|"listen"|"listens"|"look"|"looks"|"see"|"sees"|"V(read)"|"reads"|"write"|"writes"
verb_nontransitive      "work"|"works"|"sleep"|"sleeps"|"die"|"dies"
verb_misc               "V(have)"|"V(has)"|"V(like)"|"V(likes)"|"V(need)"|"V(needs)"|"V(want)"|"V(wants)"|"V(hate)"|"V(hates)"|"kill"|"kills"|"know"|"knows"|"learn"|"learns"|"meet"|"meets"
verb                    {verb_locomotion}|{verb_transaction}|{verb_communication}|{verb_nontransitive}|{verb_misc}

adjective_color         "red"|"orange"|"yellow"|"green"|"blue"|"violet"|"purple"|"black"|"white"|"brown"|"pink"
adjective_emotion       "happy"|"sad"|"angry"|"scared"|"afraid"|"disgusted"|"depressed"|"jealous"
adjective_size          "big"|"small"|"huge"|"tiny"
adjective_dimension     "tall"|"short"|"thick"|"thin"|"wide"|"narrow"|"fat"|"skinny"
adjective_speed         "quick"|"fast"|"slow"
adjective_misc          "good"|"bad"|"new"|"old"|"handsome"|"pretty"|"ugly"|"lazy"
adjective               {adjective_color}|{adjective_emotion}|{adjective_size}|{adjective_dimension}|{adjective_speed}|{adjective_misc}

%%

 /*==========*/
 /* TERMINAL */
 /*==========*/

 /*==========================================================================*/
 /* WHITE SPACE */

{ws}        {LOC;
                SCANNER_CONTEXT.m_word_index++;
            }

 /*==========================================================================*/
 /* COMMENTS */

"/*"        {
                PUSH_STATE(ST_COMMENT_BLOCK);
            }
<ST_COMMENT_BLOCK>"*/" {
                POP_STATE;
            }
<ST_COMMENT_BLOCK>{any} ;

"//"        {
                PUSH_STATE(ST_COMMENT_LINE);
            }
<ST_COMMENT_LINE>"\n" {
                POP_STATE;
            }
<ST_COMMENT_LINE>. ;

"{"         {LOC;
                PUSH_STATE(ST_ORIG_WORD);
            }
<ST_ORIG_WORD>"}" {LOC;
                POP_STATE;
            }
<ST_ORIG_WORD>{lit_ident}|{lit_char} {LOC;
                //std::cerr << "SCANNER_CONTEXT.m_orig_word: " << yytext << std::endl;
                SCANNER_CONTEXT.m_orig_word = yytext;
            }

 /*==========================================================================*/
 /* NOUN -- VERB -- ADJECTIVE */

{pronoun}|{noun} {LOC;
                LVAL.ident_value = TREE_CONTEXT.alloc_unique_string(std::string("{") + SCANNER_CONTEXT.m_orig_word + "}" + ((SCANNER_CONTEXT.m_orig_word == yytext) ? "" : yytext));
                return ID_N;
            }

{verb}      {LOC;
                LVAL.ident_value = TREE_CONTEXT.alloc_unique_string(std::string("{") + SCANNER_CONTEXT.m_orig_word + "}" + ((SCANNER_CONTEXT.m_orig_word == yytext) ? "" : yytext));
                return ID_V;
            }

{adjective} {LOC;
                LVAL.ident_value = TREE_CONTEXT.alloc_unique_string(std::string("{") + SCANNER_CONTEXT.m_orig_word + "}" + ((SCANNER_CONTEXT.m_orig_word == yytext) ? "" : yytext));
                return ID_ADJ;
            }

 /*==========================================================================*/
 /* ARTICLE */

"this"|"that"|"these"|"those" {LOC;
                LVAL.ident_value = TREE_CONTEXT.alloc_unique_string(std::string("{") + SCANNER_CONTEXT.m_orig_word + "}" + ((SCANNER_CONTEXT.m_orig_word == yytext) ? "" : yytext));
                return ID_DEM;
            }

"a"|"the"|"my"|"our"|"your"|"his"|"her"|"their" {LOC;
                LVAL.ident_value = TREE_CONTEXT.alloc_unique_string(std::string("{") + SCANNER_CONTEXT.m_orig_word + "}" + ((SCANNER_CONTEXT.m_orig_word == yytext) ? "" : yytext));
                return ID_ART_OR_PREFIXPOSS;
            }

 /*==========================================================================*/
 /* CONJUGATION */

"CLAUSE(CONJ)" {LOC;
                LVAL.ident_value = TREE_CONTEXT.alloc_unique_string(std::string("{") + SCANNER_CONTEXT.m_orig_word + "}" + ((SCANNER_CONTEXT.m_orig_word == yytext) ? "" : yytext));
                return ID_CONJ_CLAUSE;
            }

"NP(CONJ)"  {LOC;
                LVAL.ident_value = TREE_CONTEXT.alloc_unique_string(std::string("{") + SCANNER_CONTEXT.m_orig_word + "}" + ((SCANNER_CONTEXT.m_orig_word == yytext) ? "" : yytext));
                return ID_CONJ_NP;
            }

"VP(CONJ)"  {LOC;
                LVAL.ident_value = TREE_CONTEXT.alloc_unique_string(std::string("{") + SCANNER_CONTEXT.m_orig_word + "}" + ((SCANNER_CONTEXT.m_orig_word == yytext) ? "" : yytext));
                return ID_CONJ_VP;
            }

 /*==========================================================================*/
 /* PUNC */

"."|"?"|"!" {LOC;
                LVAL.ident_value = TREE_CONTEXT.alloc_unique_string(std::string("{") + SCANNER_CONTEXT.m_orig_word + "}" + ((SCANNER_CONTEXT.m_orig_word == yytext) ? "" : yytext));
                return ID_PUNC;
            }

 /*==========================================================================*/
 /* LITERALS */

{lit_ident} {LOC;
                //std::cerr << "lit_ident: " << yytext << std::endl; 
                LVAL.ident_value = TREE_CONTEXT.alloc_unique_string(yytext);
                uint32_t lexer_id = SCANNER_CONTEXT.current_lexer_id();
                //std::cout << yytext << "<" << id_to_name(lexer_id) << ">" << std::endl;
                if(lexer_id) {
                    return lexer_id;
                }
                return ID_IDENT;
            }

{lit_int}   {LOC;
                LVAL.int_value = atoi(yytext);
                return ID_INT;
            }

{lit_float} {LOC;
                LVAL.float_value = atof(yytext);
                return ID_FLOAT;
            }

{lit_char}  {LOC;
                return *yytext;
            }

 /*==========================================================================*/
 /* OTHER */

.           {LOC;
                yyerror("unknown character");
                YY_FLUSH_BUFFER;
            }

%%

void begin_token(yyscan_t yyscanner, size_t length)
{
    YYLTYPE* loc = yyget_lloc(yyscanner);
    loc->first_line    = PARM.m_line;
    loc->first_column  = PARM.m_prev_column;
    loc->last_line     = PARM.m_line;
    loc->last_column   = PARM.m_prev_column + length - 1;
    PARM.m_prev_column = PARM.m_column;
    //PARM.m_prev_column--; // compensate for 1-char over-read
}
