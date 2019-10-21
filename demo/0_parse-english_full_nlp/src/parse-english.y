// parse-english
// -- A minimum viable English parser implemented in LexYacc
// Copyright (C) 2011 onlyuser <mailto:onlyuser@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.

//%output="parse-english.tab.c"

%{

#include "parse-english.h"
#include "node/XLangNodeIFace.h" // node::NodeIdentIFace
#include "parse-englishLexerIDWrapper.h" // ID_XXX (yacc generated)
#include "XLangAlloc.h" // Allocator
#include "mvc/XLangMVCView.h" // mvc::MVCView
#include "mvc/XLangMVCModel.h" // mvc::MVCModel
#include "XLangTreeContext.h" // TreeContext
#include "XLangString.h" // xl::replace
#include "XLangType.h" // uint32_t
#include "TryAllParses.h" // gen_variations
#include "visitor/XLangVisitor.h" // visitor::Visitor
#include <Ontology.h> // NodeGatherer
#include <stdio.h> // size_t
#include <stdarg.h> // va_start
#include <string.h> // strlen
#include <vector> // std::vector
#include <list> // std::list
#include <map> // std::map
#include <string> // std::string
#include <sstream> // std::stringstream
#include <iostream> // std::cout
#include <stdlib.h> // EXIT_SUCCESS
#include <getopt.h> // getopt_long
#include <pthread.h> // pthread_t

#define DEBUG

#define MAKE_TERM(lexer_id, ...)   xl::mvc::MVCModel::make_term(&pc->tree_context(), lexer_id, ##__VA_ARGS__)
#define MAKE_SYMBOL(...)           xl::mvc::MVCModel::make_symbol(&pc->tree_context(), ##__VA_ARGS__)
#define ERROR_LEXER_ID_NOT_FOUND   "Missing lexer id handler. Did you forgot to register one?"
#define ERROR_LEXER_NAME_NOT_FOUND "Missing lexer name handler. Did you forgot to register one?"

#define NTHREADS 4
pthread_t threads[NTHREADS];
void* retvals[NTHREADS];
pthread_mutex_t graph_mutex;

// report error
void yyerror(YYLTYPE* loc, ParserContext* pc, yyscan_t scanner, const char* s)
{
    if(s && *s != '\0') {
        pc->m_error_messages << "ERROR: " << s << std::endl;
    }
    if(loc) {
        int last_line_pos = 0;
        for(int i = pc->scanner_context().m_pos; i >= 0; i--) {
            if(pc->scanner_context().m_buf[i] == '\n') {
                last_line_pos = i + 1;
                break;
            }
        }
        std::string indent = std::string(strlen("ERROR: "), ' ');
        pc->m_error_messages << indent << &pc->scanner_context().m_buf[last_line_pos] << std::endl
                             << indent << std::string(loc->first_column-1, '-') << std::string(loc->last_column - loc->first_column + 1, '^') << std::endl
                             << indent << loc->first_line << ":c" << loc->first_column << " to " << loc->last_line << ":c" << loc->last_column << std::endl;
    }
}

void yyerror(const char* s)
{
    yyerror(NULL, NULL, NULL, s);
}

std::string id_to_name(uint32_t lexer_id)
{
    static const char* _id_to_name[] = { "int",
                                         "float",
                                         "ident" };
    int index = static_cast<int>(lexer_id)-ID_BASE-1;
    if(index >= 0 && index < static_cast<int>(sizeof(_id_to_name) / sizeof(*_id_to_name))) {
        return _id_to_name[index];
    }
    switch(lexer_id) {
        // IDs for internal nodes
        case ID_S_PUNC:            return "S_PUNC";
        case ID_S:                 return "S";
        case ID_STMT:              return "STMT";
        case ID_QUERY:             return "QUERY";
        case ID_COND:              return "COND";
        case ID_CMD:               return "CMD";
        case ID_CLAUSE:            return "CLAUSE";
        case ID_QCLAUSE:           return "QCLAUSE";
        //=================================================
        // NOUN PART -- VERB PART
        case ID_NP:                return "NP";
        case ID_POSS:              return "POSS";
        case ID_VP:                return "VP";
        case ID_QVP:               return "QVP";
        case ID_CVP:               return "CVP";
        case ID_CMP:               return "CMP";
        //=================================================
        // AUXILIARY VERB
        case ID_AUX_V:             return "AUX_V";
        case ID_CAUX_V:            return "CAUX_V";
        case ID_AUX_NOT_V:         return "AUX_NOT_V";
        case ID_AUX_NP_V:          return "AUX_NP_V";
        //=================================================
        // VERB
        case ID_V_NP:              return "V_NP";
        case ID_VPAST_NP:          return "VPAST_NP";
        case ID_VGERUND_NP:        return "VGERUND_NP";
        case ID_PREP_NP:           return "PREP_NP";
        //=================================================
        // TARGET (BE -- HAVE -- MODAL -- DO)
        case ID_BE_TARGET:         return "BE_TARGET";
        case ID_HAVE_TARGET:       return "HAVE_TARGET";
        case ID_MODAL_TARGET:      return "MODAL_TARGET";
        case ID_DO_TARGET:         return "DO_TARGET";
        case ID_OPT_BE_TARGET:     return "OPT_BE_TARGET";
        case ID_FREQ_DO_TARGET:    return "FREQ_DO_TARGET";
        //=================================================
        // VERB (ADVERB)
        case ID_ADV_V_NP:          return "ADV_V_NP";
        case ID_ADV_VPAST_NP:      return "ADV_VPAST_NP";
        case ID_ADV_VGERUND_NP:    return "ADV_VGERUND_NP";
        case ID_ADV_HAVE_TARGET:   return "ADV_HAVE_TARGET";
        //=================================================
        // INFINITIVE
        case ID_INFIN:             return "INFIN";
        case ID_V_INFIN:           return "V_INFIN";
        //=================================================
        // ADJECTIVE -- ADVERB
        case ID_ADJ_N:             return "ADJ_N";
        case ID_ADV_ADJ:           return "ADV_ADJ";
        //=================================================
        // DEMONSTRATIVE -- ARTICLE/PREFIX-POSSESSIVE
        case ID_DET_ADJ_N:         return "DET_ADJ_N";
        //=================================================
        // BE -- HAVE -- MODAL -- DO (NOT)
        case ID_BE_NOT:            return "BE_NOT";
        case ID_HAVE_NOT:          return "HAVE_NOT";
        case ID_MODAL_NOT:         return "MODAL_NOT";
        case ID_DO_NOT:            return "DO_NOT";
        //=================================================
        // BE -- HAVE -- MODAL -- DO -- TO (NOT OR FREQ)
        case ID_BE_NOT_OR_FREQ:    return "BE_NOT_OR_FREQ";
        case ID_HAVE_NOT_OR_FREQ:  return "HAVE_NOT_OR_FREQ";
        case ID_MODAL_NOT_OR_FREQ: return "MODAL_NOT_OR_FREQ";
        case ID_DO_NOT_OR_FREQ:    return "DO_NOT_OR_FREQ";
        case ID_TO_NOT_OR_FREQ:    return "TO_NOT_OR_FREQ";
        //=================================================
        // BE -- HAVE -- MODAL -- DO (NOUN)
        case ID_BE_NP:             return "BE_NP";
        case ID_HAVE_NP:           return "HAVE_NP";
        case ID_MODAL_NP:          return "MODAL_NP";
        case ID_DO_NP:             return "DO_NP";
        //=================================================
        // LIST
        case ID_S_LIST:            return "S_LIST";
        case ID_CLAUSE_LIST:       return "CLAUSE_LIST";
        case ID_QCLAUSE_LIST:      return "QCLAUSE_LIST";
        case ID_CVP_LIST:          return "CVP_LIST";
        case ID_NP_LIST:           return "NP_LIST";
        case ID_VP_LIST:           return "VP_LIST";
        case ID_ADJ_LIST:          return "ADJ_LIST";
        case ID_PREP_LIST:         return "PREP_LIST";
        case ID_POSS_LIST:         return "POSS_LIST";
        //=================================================
        // CONJUGATION
        case ID_CONJ_NP_NOT:       return "CONJ_NP_NOT";
        case ID_CONJ_VP_NOT:       return "CONJ_VP_NOT";
        case ID_CONJ_ADJ_NOT:      return "CONJ_ADJ_NOT";
        case ID_CONJ_PREP_NOT:     return "CONJ_PREP_NOT";
        //=================================================
        // WH-PRONOUN
        case ID_WHPRON:            return "WHPRON";
        //=================================================
        // NOT-OR-FREQ -- EOS
        case ID_NOT_OR_FREQ:       return "NOT_OR_FREQ";
        case ID_EOS:               return "EOS";
    }
    throw ERROR_LEXER_ID_NOT_FOUND;
    return "";
}

uint32_t name_to_id(std::string name)
{
    return quick_lex(name.c_str());
}

static std::string expand_contractions(std::string &sentence)
{
    std::string s = sentence;
    s = xl::replace(s, "gonna",   "going to");
    s = xl::replace(s, "as well", "as-well");
    s = xl::replace(s, "can't",   "can not");
    s = xl::replace(s, "cannot",  "can not");
    s = xl::replace(s, "won't",   "will not");
    s = xl::replace(s, "ain't",   "am not");
    s = xl::replace(s, "n't",     " not");
    s = xl::replace(s, "n'",      "ng");
    s = xl::replace(s, "'ll",     " will");
    s = xl::replace(s, "'ve",     " have");
    s = xl::replace(s, "'m",      " am");
    s = xl::replace(s, "'re",     " are_or_were");
    s = xl::replace(s, "'d",      " did_or_had_or_would");
    s = xl::replace(s, "'s",      " is_or_has_or_poss");
    s = xl::replace(s, ",",       " , ");
    s = xl::replace(s, ".",       " . ");
    s = xl::replace(s, "?",       " ? ");
    s = xl::replace(s, "!",       " ! ");
    return s;
}

%}

// 'pure_parser' tells bison to use no global variables and create a
// reentrant parser (NOTE: deprecated, use "%define api.pure" instead).
%define      api.pure
%parse-param {ParserContext* pc}
%parse-param {yyscan_t scanner}
%lex-param   {scanner}

// show detailed parse errors
%error-verbose

// record where each token occurs in input
%locations

%nonassoc ID_BASE

%token<int_value>   ID_INT
%token<float_value> ID_FLOAT
%token<ident_value> ID_IDENT

//==============
// INTERNAL NODE
//==============

// rules for internal nodes
%type<symbol_value> S S_PUNC STMT QUERY COND CMD CLAUSE QCLAUSE
                    NP POSS VP QVP CVP CMP
                    AUX_V CAUX_V AUX_NOT_V AUX_NP_V
                        V_NP     VPAST_NP DET_ADJ_N     VGERUND_NP                 PREP_NP
                    ADV_V_NP ADV_VPAST_NP           ADV_VGERUND_NP ADV_HAVE_TARGET
                    INFIN V_INFIN
                    ADJ_N ADV_ADJ
                    BE_TARGET      HAVE_TARGET      MODAL_TARGET      DO_TARGET OPT_BE_TARGET FREQ_DO_TARGET
                    BE_NOT         HAVE_NOT         MODAL_NOT         DO_NOT
                    BE_NP          HAVE_NP          MODAL_NP          DO_NP
                    BE_NOT_OR_FREQ HAVE_NOT_OR_FREQ MODAL_NOT_OR_FREQ DO_NOT_OR_FREQ TO_NOT_OR_FREQ
                    S_LIST CLAUSE_LIST QCLAUSE_LIST CVP_LIST      NP_LIST      VP_LIST      ADJ_LIST      PREP_LIST POSS_LIST
                                                             CONJ_NP_NOT  CONJ_VP_NOT  CONJ_ADJ_NOT  CONJ_PREP_NOT
                    WHPRON
                    NOT_OR_FREQ EOS

// IDs for internal nodes
%nonassoc           ID_S ID_S_PUNC ID_STMT ID_QUERY ID_COND ID_CMD ID_CLAUSE ID_QCLAUSE
                    ID_NP ID_POSS ID_VP ID_QVP ID_CVP ID_CMP
                    ID_AUX_V ID_CAUX_V ID_AUX_NOT_V ID_AUX_NP_V
                        ID_V_NP     ID_VPAST_NP ID_DET_ADJ_N     ID_VGERUND_NP                    ID_PREP_NP
                    ID_ADV_V_NP ID_ADV_VPAST_NP              ID_ADV_VGERUND_NP ID_ADV_HAVE_TARGET
                    ID_INFIN ID_V_INFIN
                    ID_ADJ_N ID_ADV_ADJ
                    ID_BE_TARGET      ID_HAVE_TARGET      ID_MODAL_TARGET      ID_DO_TARGET ID_OPT_BE_TARGET ID_FREQ_DO_TARGET
                    ID_BE_NOT         ID_HAVE_NOT         ID_MODAL_NOT         ID_DO_NOT
                    ID_BE_NP          ID_HAVE_NP          ID_MODAL_NP          ID_DO_NP
                    ID_BE_NOT_OR_FREQ ID_HAVE_NOT_OR_FREQ ID_MODAL_NOT_OR_FREQ ID_DO_NOT_OR_FREQ ID_TO_NOT_OR_FREQ
                    ID_S_LIST ID_CLAUSE_LIST ID_QCLAUSE_LIST ID_CVP_LIST      ID_NP_LIST      ID_VP_LIST      ID_ADJ_LIST      ID_PREP_LIST ID_POSS_LIST
                                                                         ID_CONJ_NP_NOT  ID_CONJ_VP_NOT  ID_CONJ_ADJ_NOT  ID_CONJ_PREP_NOT
                    ID_WHPRON
                    ID_NOT_OR_FREQ ID_EOS

//=========
// TERMINAL
//=========

// IDs for terminals
%token<ident_value> ID_N ID_V ID_VPAST ID_VGERUND ID_GOING_MOD_INFIN ID_VPASTPERF ID_V_MOD_INFIN ID_ADJ ID_ADV_MOD_ADJ ID_ADV_MOD_V ID_ADV_MOD_VGERUND_PRE ID_ADV_MOD_VGERUND_POST ID_PREP
                    ID_DEM ID_EVERY ID_NONE ID_ART_OR_PREFIXPOSS ID_SUFFIXPOSS
                    ID_BEING ID_BEEN
                    ID_BE ID_CBE ID_HAVE ID_MODAL ID_DO ID_TO_MOD_V
                    ID_CONJ_CLAUSE ID_CONJ_NP ID_CONJ_VP ID_CONJ_ADJ ID_CONJ_PREP
                    ID_WHWORD ID_WHWORD_MOD_THAT
                    ID_CMPWORD ID_CMPWORD_EST ID_THAN ID_CMP_AS ID_CMP_LIKE ID_MOST ID_MORE
                    ID_IF ID_THEN ID_BECAUSE
                    ID_NOT ID_FREQ ID_FREQ_EOS ID_TOO ID_PUNC

// rules for terminals
%type<symbol_value> N V VPAST VGERUND GOING_MOD_INFIN VPASTPERF V_MOD_INFIN ADJ ADV_MOD_ADJ ADV_MOD_V ADV_MOD_VGERUND_PRE ADV_MOD_VGERUND_POST PREP
                    DEM EVERY NONE ART_OR_PREFIXPOSS SUFFIXPOSS
                    BEING BEEN
                    BE CBE HAVE MODAL DO TO_MOD_V
                    CONJ_CLAUSE CONJ_NP CONJ_VP CONJ_ADJ CONJ_PREP
                    WHWORD WHWORD_MOD_THAT
                    CMPWORD CMPWORD_EST THAN CMP_AS CMP_LIKE MOST MORE
                    IF THEN BECAUSE
                    NOT FREQ FREQ_EOS TOO PUNC

%%

//==============
// INTERNAL NODE
//==============

root:
      S_LIST { pc->tree_context().root() = $1; YYACCEPT; }
    | error  { yyclearin; /* yyerrok; YYABORT; */ }
    ;

S_PUNC:
      S     PUNC { $$ = MAKE_SYMBOL(ID_S_PUNC, 2, $1, $2); }
    | S EOS PUNC { $$ = MAKE_SYMBOL(ID_S_PUNC, 3, $1, $2, $3); }
    ;

S:
      STMT  { $$ = MAKE_SYMBOL(ID_S, 1, $1); }
    | QUERY { $$ = MAKE_SYMBOL(ID_S, 1, $1); }
    | COND  { $$ = MAKE_SYMBOL(ID_S, 1, $1); }
    | CMD   { $$ = MAKE_SYMBOL(ID_S, 1, $1); }
    ;

STMT:
      CLAUSE_LIST { $$ = MAKE_SYMBOL(ID_STMT, 1, $1); }
    ;

QUERY:
      QCLAUSE_LIST { $$ = MAKE_SYMBOL(ID_QUERY, 1, $1); }
    ;

COND:
      IF      CLAUSE_LIST THEN        CLAUSE_LIST { $$ = MAKE_SYMBOL(ID_COND, 4, $1, $2, $3, $4); } // if you build it then he will come
    |         CLAUSE_LIST IF          CLAUSE_LIST { $$ = MAKE_SYMBOL(ID_COND, 3, $1, $2, $3); }     // he will come if you build it
    | BECAUSE CLAUSE_LIST CONJ_CLAUSE CLAUSE_LIST { $$ = MAKE_SYMBOL(ID_COND, 4, $1, $2, $3, $4); } // because you built it, he will come
    |         CLAUSE_LIST BECAUSE     CLAUSE_LIST { $$ = MAKE_SYMBOL(ID_COND, 3, $1, $2, $3); }     // he will come because you built it
    |         AUX_NP_V    CONJ_CLAUSE CLAUSE_LIST { $$ = MAKE_SYMBOL(ID_COND, 3, $1, $2, $3); }     // had you built it, he would have come 
    ;

CMD:
      CVP_LIST { $$ = MAKE_SYMBOL(ID_CMD, 1, $1); }
    ;

CLAUSE:
                            NP_LIST VP_LIST           { $$ = MAKE_SYMBOL(ID_CLAUSE, 2, $1, $2); }         // he goes
    | PREP_LIST CONJ_CLAUSE NP_LIST VP_LIST           { $$ = MAKE_SYMBOL(ID_CLAUSE, 4, $1, $2, $3, $4); } // from there, he went
    |                       NP_LIST VP_LIST PREP_LIST { $$ = MAKE_SYMBOL(ID_CLAUSE, 3, $1, $2, $3); }     //
    ;

QCLAUSE:
             QVP { $$ = MAKE_SYMBOL(ID_QCLAUSE, 1, $1); }     // he did it?
    | WHWORD QVP { $$ = MAKE_SYMBOL(ID_QCLAUSE, 2, $1, $2); } // who did it?
    ;

//=============================================================================
// NOUN PART -- VERB PART

NP:
      POSS           { $$ = MAKE_SYMBOL(ID_NP, 1, $1); }         // the/my father
    | ADV_VGERUND_NP { $$ = MAKE_SYMBOL(ID_NP, 1, $1); }         // quickly going there
    | INFIN          { $$ = MAKE_SYMBOL(ID_NP, 1, $1); }         // to go there
    | WHPRON VP      { $$ = MAKE_SYMBOL(ID_NP, 2, $1, $2); }     // who (pronoun) was there
    | WHPRON NP VP   { $$ = MAKE_SYMBOL(ID_NP, 3, $1, $2, $3); } // who (pronoun) he is
    | PREP_LIST      { $$ = MAKE_SYMBOL(ID_NP, 1, $1); }         // from here and there
    | CMP NP         { $$ = MAKE_SYMBOL(ID_NP, 2, $1, $2); }     // bigger than he
    ;

POSS:
      DET_ADJ_N                      { $$ = MAKE_SYMBOL(ID_POSS, 1, $1); }         // the/my red apple
    | DET_ADJ_N SUFFIXPOSS POSS_LIST { $$ = MAKE_SYMBOL(ID_POSS, 3, $1, $2, $3); } // the/my father's mother's sister
    |                      POSS_LIST { $$ = MAKE_SYMBOL(ID_POSS, 1, $1); }         // father's mother's sister
    ;

VP:
        AUX_NOT_V                      { $$ = MAKE_SYMBOL(ID_VP, 1, $1); }     // is going there
    | MODAL_NOT_OR_FREQ   MODAL_TARGET { $$ = MAKE_SYMBOL(ID_VP, 2, $1, $2); } // can go there
    |    DO_NOT_OR_FREQ      DO_TARGET { $$ = MAKE_SYMBOL(ID_VP, 2, $1, $2); } // does go there
    |                   FREQ_DO_TARGET { $$ = MAKE_SYMBOL(ID_VP, 1, $1); }     // always goes there
    |                     ADV_VPAST_NP { $$ = MAKE_SYMBOL(ID_VP, 1, $1); }     // quickly went there
    ;

QVP:
        AUX_NP_V              { $$ = MAKE_SYMBOL(ID_QVP, 1, $1); }     // is he going?
    | MODAL_NP   MODAL_TARGET { $$ = MAKE_SYMBOL(ID_QVP, 2, $1, $2); } // can he go?
    |    DO_NP      DO_TARGET { $$ = MAKE_SYMBOL(ID_QVP, 2, $1, $2); } // does he go?
    ;

CVP:
      CAUX_V                        { $$ = MAKE_SYMBOL(ID_CVP, 1, $1); }     // be there!
    | DO_NOT_OR_FREQ      DO_TARGET { $$ = MAKE_SYMBOL(ID_CVP, 2, $1, $2); } // do go there!
    |                FREQ_DO_TARGET { $$ = MAKE_SYMBOL(ID_CVP, 1, $1); }     // always go there!
    ;

CMP:
      CMPWORD THAN      { $$ = MAKE_SYMBOL(ID_CMP, 2, $1, $2); }     // bigger than
    | MORE ADJ THAN     { $$ = MAKE_SYMBOL(ID_CMP, 3, $1, $2, $3); } // more big than
    | CMP_AS ADJ CMP_AS { $$ = MAKE_SYMBOL(ID_CMP, 3, $1, $2, $3); } // as big as
    | ADJ CMP_LIKE      { $$ = MAKE_SYMBOL(ID_CMP, 2, $1, $2); }     // big like
    ;

//=============================================================================
// AUXILIARY VERB

AUX_V:
           BE     OPT_BE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_V, 2, $1, $2); }     // be there
    | HAVE BEEN   OPT_BE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_V, 3, $1, $2, $3); } // has been there
    | HAVE      ADV_HAVE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_V, 2, $1, $2); }     // has quickly gone there
    ;

CAUX_V:
      CBE OPT_BE_TARGET { $$ = MAKE_SYMBOL(ID_CAUX_V, 2, $1, $2); } // be there!
    ;

AUX_NOT_V:
                       BE_NOT_OR_FREQ   OPT_BE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_NOT_V, 2, $1, $2); }     // is not there
    | HAVE_NOT_OR_FREQ BEEN             OPT_BE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_NOT_V, 3, $1, $2, $3); } // has not been there
    | HAVE_NOT_OR_FREQ                ADV_HAVE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_NOT_V, 2, $1, $2); }     // has not quickly gone there
    ;

AUX_NP_V:
              BE_NP   OPT_BE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_NP_V, 2, $1, $2); }     // is he there?
    | HAVE_NP BEEN    OPT_BE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_NP_V, 3, $1, $2, $3); } // has he been there?
    | HAVE_NP       ADV_HAVE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_NP_V, 2, $1, $2); }     // has he quickly gone there?
    ;

//=============================================================================
// VERB

V_NP:
      V            { $$ = MAKE_SYMBOL(ID_V_NP, 1, $1); }         // go
    | V NP_LIST    { $$ = MAKE_SYMBOL(ID_V_NP, 2, $1, $2); }     // go there
    | V NP      NP { $$ = MAKE_SYMBOL(ID_V_NP, 3, $1, $2, $3); } // give him it
    ;

VPAST_NP:
      VPAST            { $$ = MAKE_SYMBOL(ID_VPAST_NP, 1, $1); }         // went
    | VPAST NP_LIST    { $$ = MAKE_SYMBOL(ID_VPAST_NP, 2, $1, $2); }     // went there
    | VPAST NP      NP { $$ = MAKE_SYMBOL(ID_VPAST_NP, 3, $1, $2, $3); } // gave him it
    ;

VGERUND_NP:
      VGERUND                  { $$ = MAKE_SYMBOL(ID_VGERUND_NP, 1, $1); }         // going
    | VGERUND NP_LIST          { $$ = MAKE_SYMBOL(ID_VGERUND_NP, 2, $1, $2); }     // going there
    | VGERUND NP            NP { $$ = MAKE_SYMBOL(ID_VGERUND_NP, 3, $1, $2, $3); } // giving him it
    | BEING   OPT_BE_TARGET    { $$ = MAKE_SYMBOL(ID_VGERUND_NP, 2, $1, $2); }     // being there
    ;

PREP_NP:
      PREP NP_LIST { $$ = MAKE_SYMBOL(ID_PREP_NP, 2, $1, $2); } // from there
                                                                // NOTE: using NP_LIST here causes shift-reduce conflict because NP ==> PREP_NP ==> NP
                                                                //       however, not having NP_LIST here makes parsing "from here and there.." impossible
    ;

//=============================================================================
// TARGET (BE -- HAVE -- MODAL -- DO)

BE_TARGET:
      ADV_HAVE_TARGET       { $$ = MAKE_SYMBOL(ID_BE_TARGET, 1, $1); }     // quickly gone there
    | GOING_MOD_INFIN INFIN { $$ = MAKE_SYMBOL(ID_BE_TARGET, 2, $1, $2); } // going to go there
    | NP_LIST               { $$ = MAKE_SYMBOL(ID_BE_TARGET, 1, $1); }
    | ADJ_LIST              { $$ = MAKE_SYMBOL(ID_BE_TARGET, 1, $1); }
    | CMPWORD               { $$ = MAKE_SYMBOL(ID_BE_TARGET, 1, $1); }     // bigger
    ;

HAVE_TARGET:
      VPASTPERF         { $$ = MAKE_SYMBOL(ID_HAVE_TARGET, 1, $1); }     // gone
    | VPASTPERF NP_LIST { $$ = MAKE_SYMBOL(ID_HAVE_TARGET, 2, $1, $2); } // gone there
    ;

MODAL_TARGET:
      DO_TARGET { $$ = MAKE_SYMBOL(ID_MODAL_TARGET, 1, $1); } // go there
    | AUX_V     { $$ = MAKE_SYMBOL(ID_MODAL_TARGET, 1, $1); } // be there
    ;

DO_TARGET:
      ADV_V_NP { $$ = MAKE_SYMBOL(ID_DO_TARGET, 1, $1); } // quickly go there
    | V_INFIN  { $$ = MAKE_SYMBOL(ID_DO_TARGET, 1, $1); } // like to go there
    ;

OPT_BE_TARGET:
      /* empty */ { $$ = xl::node::SymbolNode::eol(); }
    | BE_TARGET   { $$ = MAKE_SYMBOL(ID_OPT_BE_TARGET, 1, $1); } // there
    ;

FREQ_DO_TARGET:
           DO_TARGET { $$ = MAKE_SYMBOL(ID_FREQ_DO_TARGET, 1, $1); }     // quickly go there
    | FREQ DO_TARGET { $$ = MAKE_SYMBOL(ID_FREQ_DO_TARGET, 2, $1, $2); } // always quickly go there
    ;

//=============================================================================
// VERB (ADVERB)

ADV_V_NP:
                V_NP           { $$ = MAKE_SYMBOL(ID_ADV_V_NP, 1, $1); }     // go there
    | ADV_MOD_V V_NP           { $$ = MAKE_SYMBOL(ID_ADV_V_NP, 2, $1, $2); } // quickly go there
    |           V_NP ADV_MOD_V { $$ = MAKE_SYMBOL(ID_ADV_V_NP, 2, $1, $2); } // go there quickly
    ;

ADV_VPAST_NP:
                VPAST_NP           { $$ = MAKE_SYMBOL(ID_ADV_VPAST_NP, 1, $1); }     // went there
    | ADV_MOD_V VPAST_NP           { $$ = MAKE_SYMBOL(ID_ADV_VPAST_NP, 2, $1, $2); } // quickly went there
    |           VPAST_NP ADV_MOD_V { $$ = MAKE_SYMBOL(ID_ADV_VPAST_NP, 2, $1, $2); } // went there quickly
    ;

ADV_VGERUND_NP:
                          VGERUND_NP                      { $$ = MAKE_SYMBOL(ID_ADV_VGERUND_NP, 1, $1); }     // going there
    | ADV_MOD_VGERUND_PRE VGERUND_NP                      { $$ = MAKE_SYMBOL(ID_ADV_VGERUND_NP, 2, $1, $2); } // quickly going there
    |                     VGERUND_NP ADV_MOD_VGERUND_POST { $$ = MAKE_SYMBOL(ID_ADV_VGERUND_NP, 2, $1, $2); } // going there quickly
    ;

ADV_HAVE_TARGET:
                HAVE_TARGET           { $$ = MAKE_SYMBOL(ID_ADV_HAVE_TARGET, 1, $1); }     // gone there
    | ADV_MOD_V HAVE_TARGET           { $$ = MAKE_SYMBOL(ID_ADV_HAVE_TARGET, 2, $1, $2); } // quickly gone there
    |           HAVE_TARGET ADV_MOD_V { $$ = MAKE_SYMBOL(ID_ADV_HAVE_TARGET, 2, $1, $2); } // gone there quickly
    ;

//=============================================================================
// INFINITIVE

INFIN:
      TO_NOT_OR_FREQ MODAL_TARGET { $$ = MAKE_SYMBOL(ID_INFIN, 2, $1, $2); } // to go there
    ;

V_INFIN:
      V_MOD_INFIN INFIN { $$ = MAKE_SYMBOL(ID_V_INFIN, 2, $1, $2); } // have to go there
    ;

//=============================================================================
// ADJECTIVE -- ADVERB

ADJ_N:
               N { $$ = MAKE_SYMBOL(ID_ADJ_N, 1, $1); }     // apple
    | ADJ_LIST N { $$ = MAKE_SYMBOL(ID_ADJ_N, 2, $1, $2); } // red apple
    ;

ADV_ADJ:
                  ADJ { $$ = MAKE_SYMBOL(ID_ADV_ADJ, 1, $1); }     // red
    | ADV_MOD_ADJ ADJ { $$ = MAKE_SYMBOL(ID_ADV_ADJ, 2, $1, $2); } // very red
    ;

//=============================================================================
// DEMONSTRATIVE -- ARTICLE/PREFIX-POSSESSIVE

DET_ADJ_N:
      DEM                                 { $$ = MAKE_SYMBOL(ID_DET_ADJ_N, 1, $1); }             // this
    | DEM                           ADJ_N { $$ = MAKE_SYMBOL(ID_DET_ADJ_N, 2, $1, $2); }         // this red apple
    | NONE                                { $$ = MAKE_SYMBOL(ID_DET_ADJ_N, 1, $1); }             // none
    | EVERY                         ADJ_N { $$ = MAKE_SYMBOL(ID_DET_ADJ_N, 2, $1, $2); }         // every red apple
    | ART_OR_PREFIXPOSS             ADJ_N { $$ = MAKE_SYMBOL(ID_DET_ADJ_N, 2, $1, $2); }         // the red apple
    | ART_OR_PREFIXPOSS CMPWORD_EST       { $$ = MAKE_SYMBOL(ID_DET_ADJ_N, 2, $1, $2); }         // the best
    | ART_OR_PREFIXPOSS CMPWORD_EST     N { $$ = MAKE_SYMBOL(ID_DET_ADJ_N, 3, $1, $2, $3); }     // the best thing
    | ART_OR_PREFIXPOSS MOST ADJ          { $$ = MAKE_SYMBOL(ID_DET_ADJ_N, 3, $1, $2, $3); }     // the most red
    | ART_OR_PREFIXPOSS MOST ADJ        N { $$ = MAKE_SYMBOL(ID_DET_ADJ_N, 4, $1, $2, $3, $4); } // the most red apple
    ;

//=============================================================================
// BE -- HAVE -- MODAL -- DO (NOT)

BE_NOT:
      BE     { $$ = MAKE_SYMBOL(ID_BE_NOT, 1, $1); }     // is
    | BE NOT { $$ = MAKE_SYMBOL(ID_BE_NOT, 2, $1, $2); } // is not
    ;

HAVE_NOT:
      HAVE     { $$ = MAKE_SYMBOL(ID_HAVE_NOT, 1, $1); }     // have
    | HAVE NOT { $$ = MAKE_SYMBOL(ID_HAVE_NOT, 2, $1, $2); } // have not
    ;

MODAL_NOT:
      MODAL     { $$ = MAKE_SYMBOL(ID_MODAL_NOT, 1, $1); }     // can
    | MODAL NOT { $$ = MAKE_SYMBOL(ID_MODAL_NOT, 2, $1, $2); } // can not
    ;

DO_NOT:
      DO     { $$ = MAKE_SYMBOL(ID_DO_NOT, 1, $1); }     // do
    | DO NOT { $$ = MAKE_SYMBOL(ID_DO_NOT, 2, $1, $2); } // do not
    ;

//=============================================================================
// BE -- HAVE -- MODAL -- DO (NOT NOUN FREQ)

BE_NP:
      BE_NOT NP_LIST      { $$ = MAKE_SYMBOL(ID_BE_NP, 2, $1, $2); }     // is he
    | BE_NOT NP_LIST FREQ { $$ = MAKE_SYMBOL(ID_BE_NP, 3, $1, $2, $3); } // is he always
    ;

HAVE_NP:
      HAVE_NOT NP_LIST      { $$ = MAKE_SYMBOL(ID_HAVE_NP, 2, $1, $2); }     // has he
    | HAVE_NOT NP_LIST FREQ { $$ = MAKE_SYMBOL(ID_HAVE_NP, 3, $1, $2, $3); } // has he always
    ;

MODAL_NP:
      MODAL_NOT NP_LIST      { $$ = MAKE_SYMBOL(ID_MODAL_NP, 2, $1, $2); }     // can he
    | MODAL_NOT NP_LIST FREQ { $$ = MAKE_SYMBOL(ID_MODAL_NP, 3, $1, $2, $3); } // can he always
    ;

DO_NP:
      DO_NOT NP_LIST      { $$ = MAKE_SYMBOL(ID_DO_NP, 2, $1, $2); }     // does he
    | DO_NOT NP_LIST FREQ { $$ = MAKE_SYMBOL(ID_DO_NP, 3, $1, $2, $3); } // does he always
    ;

//=============================================================================
// BE -- HAVE -- MODAL -- DO -- TO (NOT OR FREQ)

BE_NOT_OR_FREQ:
      BE             { $$ = MAKE_SYMBOL(ID_BE_NOT_OR_FREQ, 1, $1); }     // is
    | BE NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_BE_NOT_OR_FREQ, 2, $1, $2); } // is not
    ;

HAVE_NOT_OR_FREQ:
      HAVE             { $$ = MAKE_SYMBOL(ID_HAVE_NOT_OR_FREQ, 1, $1); }     // have
    | HAVE NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_HAVE_NOT_OR_FREQ, 2, $1, $2); } // have not
    ;

MODAL_NOT_OR_FREQ:
      MODAL             { $$ = MAKE_SYMBOL(ID_MODAL_NOT_OR_FREQ, 1, $1); }     // can
    | MODAL NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_MODAL_NOT_OR_FREQ, 2, $1, $2); } // can not
    ;

DO_NOT_OR_FREQ:
      DO             { $$ = MAKE_SYMBOL(ID_DO_NOT_OR_FREQ, 1, $1); }     // do
    | DO NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_DO_NOT_OR_FREQ, 2, $1, $2); } // do not
    ;

TO_NOT_OR_FREQ:
      TO_MOD_V             { $$ = MAKE_SYMBOL(ID_TO_NOT_OR_FREQ, 1, $1); }     // to
    | TO_MOD_V NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_TO_NOT_OR_FREQ, 2, $1, $2); } // to not
    ;

//=============================================================================
// LIST

S_LIST:
             S_PUNC { $$ = MAKE_SYMBOL(ID_S_LIST, 1, $1); }
    | S_LIST S_PUNC { $$ = MAKE_SYMBOL(ID_S_LIST, 2, $1, $2); }
    ;

CLAUSE_LIST:
                              CLAUSE { $$ = MAKE_SYMBOL(ID_CLAUSE_LIST, 1, $1); }
    | CLAUSE_LIST CONJ_CLAUSE CLAUSE { $$ = MAKE_SYMBOL(ID_CLAUSE_LIST, 3, $1, $2, $3); }
    ;

QCLAUSE_LIST:
                               QCLAUSE { $$ = MAKE_SYMBOL(ID_QCLAUSE_LIST, 1, $1); }
    | QCLAUSE_LIST CONJ_CLAUSE QCLAUSE { $$ = MAKE_SYMBOL(ID_QCLAUSE_LIST, 3, $1, $2, $3); }
    ;

CVP_LIST:
                           CVP { $$ = MAKE_SYMBOL(ID_CVP_LIST, 1, $1); }
    | CVP_LIST CONJ_CLAUSE CVP { $$ = MAKE_SYMBOL(ID_CVP_LIST, 3, $1, $2, $3); }
    ;

NP_LIST:
                          NP { $$ = MAKE_SYMBOL(ID_NP_LIST, 1, $1); }
    | NP_LIST CONJ_NP_NOT NP { $$ = MAKE_SYMBOL(ID_NP_LIST, 3, $1, $2, $3); }
    ;

VP_LIST:
                          VP { $$ = MAKE_SYMBOL(ID_VP_LIST, 1, $1); }
    | VP_LIST CONJ_VP_NOT VP { $$ = MAKE_SYMBOL(ID_VP_LIST, 3, $1, $2, $3); }
    ;

ADJ_LIST:
                            ADV_ADJ { $$ = MAKE_SYMBOL(ID_ADJ_LIST, 1, $1); }
    | ADJ_LIST              ADV_ADJ { $$ = MAKE_SYMBOL(ID_ADJ_LIST, 2, $1, $2); }
    | ADJ_LIST CONJ_ADJ_NOT ADV_ADJ { $$ = MAKE_SYMBOL(ID_ADJ_LIST, 3, $1, $2, $3); }
    ;

PREP_LIST:
                              PREP_NP { $$ = MAKE_SYMBOL(ID_PREP_LIST, 1, $1); }
    | PREP_LIST CONJ_PREP_NOT PREP_NP { $$ = MAKE_SYMBOL(ID_PREP_LIST, 3, $1, $2, $3); }
    ;

POSS_LIST:
                           ADJ_N { $$ = MAKE_SYMBOL(ID_POSS_LIST, 1, $1); }
    | POSS_LIST SUFFIXPOSS ADJ_N { $$ = MAKE_SYMBOL(ID_POSS_LIST, 3, $1, $2, $3); }
    ;

//=============================================================================
// CONJUGATION

CONJ_NP_NOT:
      CONJ_NP             { $$ = MAKE_SYMBOL(ID_CONJ_NP_NOT, 1, $1); }     // and
    | CONJ_NP NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_CONJ_NP_NOT, 2, $1, $2); } // and not
    ;

CONJ_VP_NOT:
      CONJ_VP             { $$ = MAKE_SYMBOL(ID_CONJ_VP_NOT, 1, $1); }     // and
    | CONJ_VP NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_CONJ_VP_NOT, 2, $1, $2); } // and not
    ;

CONJ_ADJ_NOT:
      CONJ_ADJ             { $$ = MAKE_SYMBOL(ID_CONJ_ADJ_NOT, 1, $1); }     // and
    | CONJ_ADJ NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_CONJ_ADJ_NOT, 2, $1, $2); } // and not
    ;

CONJ_PREP_NOT:
      CONJ_PREP             { $$ = MAKE_SYMBOL(ID_CONJ_PREP_NOT, 1, $1); }     // and
    | CONJ_PREP NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_CONJ_PREP_NOT, 2, $1, $2); } // and not
    ;

//=============================================================================
// WH-PRONOUN

WHPRON:
      WHWORD          { $$ = MAKE_SYMBOL(ID_WHPRON, 1, $1); } // who (pronoun)
    | WHWORD_MOD_THAT { $$ = MAKE_SYMBOL(ID_WHPRON, 1, $1); } // who (pronoun)
    ;

//=============================================================================
 /* NOT-OR-FREQ -- EOS */

NOT_OR_FREQ:
      NOT      { $$ = MAKE_SYMBOL(ID_NOT_OR_FREQ, 1, $1); }     // not
    | NOT FREQ { $$ = MAKE_SYMBOL(ID_NOT_OR_FREQ, 2, $1, $2); } // not always
    |     FREQ { $$ = MAKE_SYMBOL(ID_NOT_OR_FREQ, 1, $1); }     // always
    ;

EOS:
      TOO      { $$ = MAKE_SYMBOL(ID_EOS, 1, $1); } // too
    | FREQ_EOS { $$ = MAKE_SYMBOL(ID_EOS, 1, $1); } // always
    ;

//=========
// TERMINAL
//=========

//=============================================================================
// NOUN -- VERB -- ADJECTIVE -- ADVERB -- PREPOSITION

N:
      ID_N { $$ = MAKE_TERM(ID_N, $1); }
    ;

V:
      ID_V { $$ = MAKE_TERM(ID_V, $1); }
    ;

VPAST:
      ID_VPAST { $$ = MAKE_TERM(ID_VPAST, $1); }
    ;

VGERUND:
      ID_VGERUND { $$ = MAKE_TERM(ID_VGERUND, $1); }
    ;

GOING_MOD_INFIN:
      ID_GOING_MOD_INFIN { $$ = MAKE_TERM(ID_GOING_MOD_INFIN, $1); }
    ;

VPASTPERF:
      ID_VPASTPERF { $$ = MAKE_TERM(ID_VPASTPERF, $1); }
    ;

V_MOD_INFIN:
      ID_V_MOD_INFIN { $$ = MAKE_TERM(ID_V_MOD_INFIN, $1); }
    ;

ADJ:
      ID_ADJ { $$ = MAKE_TERM(ID_ADJ, $1); }
    ;

ADV_MOD_ADJ:
      ID_ADV_MOD_ADJ { $$ = MAKE_TERM(ID_ADV_MOD_ADJ, $1); }
    ;

ADV_MOD_V:
      ID_ADV_MOD_V { $$ = MAKE_TERM(ID_ADV_MOD_V, $1); }
    ;

ADV_MOD_VGERUND_PRE:
      ID_ADV_MOD_VGERUND_PRE { $$ = MAKE_TERM(ID_ADV_MOD_VGERUND_PRE, $1); }
    ;

ADV_MOD_VGERUND_POST:
      ID_ADV_MOD_VGERUND_POST { $$ = MAKE_TERM(ID_ADV_MOD_VGERUND_POST, $1); }
    ;

PREP:
      ID_PREP { $$ = MAKE_TERM(ID_PREP, $1); }
    ;

//=============================================================================
// DEMONSTRATIVE -- ARTICLE/PREFIX-POSSESSIVE

DEM:
      ID_DEM { $$ = MAKE_TERM(ID_DEM, $1); }
    ;

EVERY:
      ID_EVERY { $$ = MAKE_TERM(ID_EVERY, $1); }
    ;

NONE:
      ID_NONE { $$ = MAKE_TERM(ID_NONE, $1); }
    ;

ART_OR_PREFIXPOSS:
      ID_ART_OR_PREFIXPOSS { $$ = MAKE_TERM(ID_ART_OR_PREFIXPOSS, $1); }
    ;

SUFFIXPOSS:
      ID_SUFFIXPOSS { $$ = MAKE_TERM(ID_SUFFIXPOSS, $1); }
    ;

//=============================================================================
// BE

BEING:
      ID_BEING { $$ = MAKE_TERM(ID_BEING, $1); }
    ;

BEEN:
      ID_BEEN { $$ = MAKE_TERM(ID_BEEN, $1); }
    ;

//=============================================================================
// BE -- HAVE -- MODAL -- DO -- TO

BE:
      ID_BE { $$ = MAKE_TERM(ID_BE, $1); }
    ;

CBE:
      ID_CBE { $$ = MAKE_TERM(ID_CBE, $1); }
    ;

HAVE:
      ID_HAVE { $$ = MAKE_TERM(ID_HAVE, $1); }
    ;

MODAL:
      ID_MODAL { $$ = MAKE_TERM(ID_MODAL, $1); }
    ;

DO:
      ID_DO { $$ = MAKE_TERM(ID_DO, $1); }
    ;

TO_MOD_V:
      ID_TO_MOD_V { $$ = MAKE_TERM(ID_TO_MOD_V, $1); }
    ;

//=============================================================================
// CONJUGATION

CONJ_CLAUSE:
      ID_CONJ_CLAUSE { $$ = MAKE_TERM(ID_CONJ_CLAUSE, $1); }
    ;

CONJ_NP:
      ID_CONJ_NP { $$ = MAKE_TERM(ID_CONJ_NP, $1); }
    ;

CONJ_VP:
      ID_CONJ_VP { $$ = MAKE_TERM(ID_CONJ_VP, $1); }
    ;

CONJ_ADJ:
      ID_CONJ_ADJ { $$ = MAKE_TERM(ID_CONJ_ADJ, $1); }
    ;

CONJ_PREP:
      ID_CONJ_PREP { $$ = MAKE_TERM(ID_CONJ_PREP, $1); }
    ;

//=============================================================================
// WH-WORD

WHWORD:
      ID_WHWORD { $$ = MAKE_TERM(ID_WHWORD, $1); } // who
    ;

WHWORD_MOD_THAT:
      ID_WHWORD_MOD_THAT { $$ = MAKE_TERM(ID_WHWORD_MOD_THAT, $1); } // that
    ;

//=============================================================================
// CMP-WORD

CMPWORD:
      ID_CMPWORD { $$ = MAKE_TERM(ID_CMPWORD, $1); } // bigger
    ;

CMPWORD_EST:
      ID_CMPWORD_EST { $$ = MAKE_TERM(ID_CMPWORD_EST, $1); } // biggest
    ;

THAN:
      ID_THAN { $$ = MAKE_TERM(ID_THAN, $1); } // than
    ;

CMP_AS:
      ID_CMP_AS { $$ = MAKE_TERM(ID_CMP_AS, $1); } // as
    ;

CMP_LIKE:
      ID_CMP_LIKE { $$ = MAKE_TERM(ID_CMP_LIKE, $1); } // like
    ;

MOST:
      ID_MOST { $$ = MAKE_TERM(ID_MOST, $1); } // most
    ;

MORE:
      ID_MORE { $$ = MAKE_TERM(ID_MORE, $1); } // more
    ;

//=============================================================================
// COND

IF:
      ID_IF { $$ = MAKE_TERM(ID_IF, $1); }
    ;

THEN:
      ID_THEN { $$ = MAKE_TERM(ID_THEN, $1); }
    ;

BECAUSE:
      ID_BECAUSE { $$ = MAKE_TERM(ID_BECAUSE, $1); }
    ;

 /*==========================================================================*/
 /* NOT -- FREQ -- TOO -- PUNC */

NOT:
      ID_NOT { $$ = MAKE_TERM(ID_NOT, $1); }
    ;

FREQ:
      ID_FREQ { $$ = MAKE_TERM(ID_FREQ, $1); }
    ;

FREQ_EOS:
      ID_FREQ_EOS { $$ = MAKE_TERM(ID_FREQ_EOS, $1); }
    ;

TOO:
      ID_TOO { $$ = MAKE_TERM(ID_TOO, $1); }
    ;

PUNC:
      ID_PUNC { $$ = MAKE_TERM(ID_PUNC, $1); }
    ;

%%

ScannerContext::ScannerContext(const char* buf)
    : m_scanner(NULL), m_buf(buf), m_pos(0), m_length(strlen(buf)),
      m_line(1), m_column(1), m_prev_column(1), m_word_index(0),
      m_pos_lexer_id_path(NULL)
{}

uint32_t ScannerContext::current_lexer_id()
{
    if(!m_pos_lexer_id_path) {
        throw ERROR_LEXER_ID_NOT_FOUND;
        return 0;
    }
    return (*m_pos_lexer_id_path)[m_word_index];
}

uint32_t quick_lex(const char* s)
{
    xl::Allocator alloc(__FILE__);
    ParserContext parser_context(alloc, s);
    yyscan_t scanner = parser_context.scanner_context().m_scanner;
    yylex_init(&scanner);
    yyset_extra(&parser_context, scanner);
    YYSTYPE dummy_sa;
    YYLTYPE dummy_loc;
    uint32_t lexer_id = yylex(&dummy_sa, &dummy_loc, scanner); // scanner entry point
    yylex_destroy(scanner);
    return lexer_id;
}

xl::node::NodeIdentIFace* make_ast(xl::Allocator         &alloc,
                                   const char*            s,
                                   std::vector<uint32_t> &pos_lexer_id_path,
                                   std::stringstream     &error_messages)
{
    ParserContext parser_context(alloc, s);
    parser_context.scanner_context().m_pos_lexer_id_path = &pos_lexer_id_path;
    yyscan_t scanner = parser_context.scanner_context().m_scanner;
    yylex_init(&scanner);
    yyset_extra(&parser_context, scanner);
    int error_code = yyparse(&parser_context, scanner); // parser entry point
    yylex_destroy(scanner);
    error_messages << parser_context.m_error_messages.str();
    return (!error_code && parser_context.m_error_messages.str().empty()) ? parser_context.tree_context().root() : NULL;
}

void display_usage(bool verbose)
{
    std::cout << "Usage: parse-english [-i] OPTION [-m]" << std::endl;
    if(verbose) {
        std::cout << "Parses input and prints a syntax tree to standard out" << std::endl
                  << std::endl
                  << "Input control:" << std::endl
                  << "  -e, --expr EXPRESSION" << std::endl
                  << std::endl
                  << "Output control:" << std::endl
                  << "  -l, --lisp" << std::endl
                  << "  -g, --graph" << std::endl
                  << "  -d, --dot" << std::endl
                  << "  -x, --extract" << std::endl
                  << "  -q, --quiet" << std::endl
                  << "  -m, --memory" << std::endl
                  << "  -h, --help" << std::endl
                  << std::endl
                  << "Example:" << std::endl
                  << "  ./parse-english -e \"the quick brown fox jumps over the lazy dog\" -d | dot -Tpng > qwe.png; xdg-open qwe.png" << std::endl;
        return;
    }
    std::cout << "Try `parse-english --help\' for more information." << std::endl;
}

struct options_t
{
    typedef enum
    {
        MODE_NONE,
        MODE_LISP,
        MODE_GRAPH,
        MODE_DOT,
        MODE_EXTRACT,
        MODE_HELP
    } mode_e;

    mode_e      mode;
    std::string expr;
    bool        dump_memory;
    bool        quiet;
    bool        indent;
    bool        serial;

    options_t()
        : mode(MODE_NONE),
          dump_memory(false),
          quiet(false),
          indent(false),
          serial(false)
    {}
};

bool extract_options_from_args(options_t* options, int argc, char** argv)
{
    if(!options) {
        return false;
    }
    int opt = 0;
    int longIndex = 0;
    static const char *optString = "e:lgdxqmnsh?";
    static const struct option longOpts[] = { { "expr",    required_argument, NULL, 'e' },
                                              { "lisp",    no_argument,       NULL, 'l' },
                                              { "graph",   no_argument,       NULL, 'g' },
                                              { "dot",     no_argument,       NULL, 'd' },
                                              { "extract", no_argument,       NULL, 'x' },
                                              { "quiet",   no_argument,       NULL, 'q' },
                                              { "memory",  no_argument,       NULL, 'm' },
                                              { "indent",  no_argument,       NULL, 'n' },
                                              { "serial",  no_argument,       NULL, 's' },
                                              { "help",    no_argument,       NULL, 'h' },
                                              { NULL,      no_argument,       NULL, 0   } };
    opt = getopt_long(argc, argv, optString, longOpts, &longIndex);
    while(opt != -1) {
        switch(opt) {
            case 'e': options->expr = optarg; break;
            case 'l': options->mode = options_t::MODE_LISP; break;
            case 'g': options->mode = options_t::MODE_GRAPH; break;
            case 'd': options->mode = options_t::MODE_DOT; break;
            case 'x': options->mode = options_t::MODE_EXTRACT; break;
            case 'q': options->quiet = true; break;
            case 'm': options->dump_memory = true; break;
            case 'n': options->indent = true; break;
            case 's': options->serial = true; break;
            case 'h':
            case '?': options->mode = options_t::MODE_HELP; break;
            case 0: // reserved
            default:
                break;
        }
        opt = getopt_long(argc, argv, optString, longOpts, &longIndex);
    }
    return options->mode != options_t::MODE_NONE || options->dump_memory;
}

struct pos_path_ast_tuple_t
{
    std::vector<std::string>  m_pos_path;
    xl::node::NodeIdentIFace* m_ast;
    int                       m_path_index;

    pos_path_ast_tuple_t(
            std::vector<std::string>  &pos_path,
            xl::node::NodeIdentIFace*  ast,
            int                        path_index)
        : m_pos_path(pos_path),
          m_ast(ast),
          m_path_index(path_index) {}
};

struct job_context_t
{
    options_t*           m_options;
    pos_path_ast_tuple_t m_pos_path_ast_tuple;
    std::stringstream*   m_shared_header;
    std::stringstream*   m_shared_footer;
    xl::Allocator        m_alloc;
    std::stringstream    m_output;
    std::stringstream    m_info_messages;
    std::stringstream    m_error_messages;

    job_context_t(options_t*           options,
                  pos_path_ast_tuple_t pos_path_ast_tuple,
                  std::stringstream*   shared_header = NULL,
                  std::stringstream*   shared_footer = NULL)
        : m_options(options),
          m_pos_path_ast_tuple(pos_path_ast_tuple),
          m_shared_header(shared_header),
          m_shared_footer(shared_footer),
          m_alloc(__FILE__) {}
};

bool filter_node(const xl::node::NodeIdentIFace* node)
{
    if(node->type() == xl::node::NodeIdentIFace::SYMBOL) {
        std::cout << node->name() << std::endl;
        return true;
    }
    if(node->type() == xl::node::NodeIdentIFace::IDENT) {
        std::cout << *dynamic_cast<const xl::node::TermNodeIFace<xl::node::NodeIdentIFace::IDENT>*>(node)->value() << std::endl;
    }
    return true;
}

bool import_ast(options_t             &options,
                xl::Allocator         &alloc,
                pos_path_ast_tuple_t*  pos_path_ast_tuple,
                std::stringstream     &info_messages,
                std::stringstream     &error_messages)
{
    if(!pos_path_ast_tuple) {
        return false;
    }
    std::vector<std::string> &pos_path = pos_path_ast_tuple->m_pos_path;
    std::string pos_path_str;
    for(std::vector<std::string>::iterator p = pos_path.begin(); p != pos_path.end(); p++) {
        pos_path_str.append(*p + " ");
    }
    info_messages << "INFO: Importing path #" << pos_path_ast_tuple->m_path_index << ": " << pos_path_str << std::endl;
    std::vector<uint32_t> pos_lexer_id_path;
    for(std::vector<std::string>::const_iterator p = pos_path.begin(); p != pos_path.end(); p++) {
        pos_lexer_id_path.push_back(name_to_id(*p));
    }
#if 1
    // NOTE: doesn't depend on SCANNER_CONTEXT.current_lexer_id()
    xl::node::NodeIdentIFace* ast = make_ast(alloc, pos_path_str.c_str(), pos_lexer_id_path, error_messages);
#else
    // NOTE: depends on SCANNER_CONTEXT.current_lexer_id()
    xl::node::NodeIdentIFace* ast = make_ast(alloc, options.expr.c_str(), pos_lexer_id_path, error_messages);
#endif
    if(!ast) {
        pos_path_ast_tuple->m_ast = NULL;
        error_messages << "ERROR: Failed to import path #" << pos_path_ast_tuple->m_path_index << std::endl;
        return false;
    }
    pos_path_ast_tuple->m_ast = ast;
    info_messages << "INFO: Successfully imported path #" << pos_path_ast_tuple->m_path_index << std::endl;
    return true;
}

bool export_ast(options_t            &options,
                pos_path_ast_tuple_t &pos_path_ast_tuple,
                std::stringstream    &output,
                std::stringstream    &info_messages)
{
    xl::node::NodeIdentIFace* ast = pos_path_ast_tuple.m_ast;
    if(!ast) {
        return false;
    }
    std::vector<std::string> &pos_path = pos_path_ast_tuple.m_pos_path;
    std::string pos_path_str;
    for(std::vector<std::string>::iterator p = pos_path.begin(); p != pos_path.end(); p++) {
        pos_path_str.append(*p + " ");
    }
    info_messages << "INFO: Exporting path #" << pos_path_ast_tuple.m_path_index << ": " << pos_path_str << std::endl;
    switch(options.mode) {
        case options_t::MODE_LISP:  output << xl::mvc::MVCView::print_lisp(ast, options.indent); break;
        case options_t::MODE_GRAPH: output << xl::mvc::MVCView::print_graph(ast); break;
        case options_t::MODE_DOT:   output << xl::mvc::MVCView::print_dot(ast, false, false); break;
        case options_t::MODE_EXTRACT:
            {
                output << std::endl;
                std::vector<Sentence*> sentences = extract_ontology(ast);
                if(sentences.size()) {
                    output << "(SENTENCES" << std::endl;
                    for(std::vector<Sentence*>::iterator p = sentences.begin(); p != sentences.end(); p++) {
                        output << (*p)->to_string(1);
                        delete *p;
                    }
                    output << ")" << std::endl << std::endl;
                }
                break;
            }
        default:
            break;
    }
    info_messages << "INFO: Successfully exported path #" << pos_path_ast_tuple.m_path_index << std::endl;
    return true;
}

void* do_job(void* args)
{
    job_context_t* job = reinterpret_cast<job_context_t*>(args);
    do {
        try {
            if(!import_ast(*job->m_options, job->m_alloc, &job->m_pos_path_ast_tuple,
                                                           job->m_info_messages,
                                                           job->m_error_messages))
            {
                break;
            }
        } catch(const char* s) {
            job->m_error_messages << "ERROR: " << s << std::endl;
            break;
        }
        pthread_mutex_lock(&graph_mutex);
        if(job->m_options->mode == options_t::MODE_DOT) {
            if(job->m_shared_header && (*job->m_shared_header).str().empty()) {
                *job->m_shared_header << xl::mvc::MVCView::print_dot_header(false);
            }
            export_ast(*job->m_options, job->m_pos_path_ast_tuple,
                                        job->m_output,
                                        job->m_info_messages);
            if(job->m_shared_footer && (*job->m_shared_footer).str().empty()) {
                *job->m_shared_footer << xl::mvc::MVCView::print_dot_footer();
            }
        } else {
            export_ast(*job->m_options, job->m_pos_path_ast_tuple,
                                        job->m_output,
                                        job->m_info_messages);
        }
        pthread_mutex_unlock(&graph_mutex);
    } while(0);
    if(job->m_options->dump_memory) {
        job->m_info_messages << job->m_alloc.dump(std::string(1, '\t'));
    }
    return NULL;
}

void process_batch_jobs(std::vector<job_context_t*>& batch_jobs)
{
    pthread_mutex_init(&graph_mutex, NULL);
    for(int i = 0; i < static_cast<int>(batch_jobs.size()); ++i) {
        if(pthread_create(&threads[i], NULL, do_job, batch_jobs[i]) != 0) {
            fprintf(stderr, "ERROR: Failed to create thread: %d\n", i);
            break;
        }
    }
    for(int j = 0; j < static_cast<int>(batch_jobs.size()); ++j) {
        if(pthread_join(threads[j], &retvals[j]) != 0) {
            fprintf(stderr, "ERROR: Failed to join thread: %d\n", j);
        }
    }
    pthread_mutex_destroy(&graph_mutex);
}

bool apply_options(options_t &options)
{
    if(options.mode == options_t::MODE_HELP) {
        display_usage(true);
        return true;
    }
    if(options.expr.empty()) {
        if(!options.quiet) {
            std::cerr << "ERROR: mode not supported!" << std::endl;
        }
        return false;
    }
    std::list<std::vector<std::string>> all_paths_str;
    std::string sentence = options.expr;
// NOTE: just in case
#if 1
    size_t n = sentence.length();
    if(n && sentence[n - 1] != '.' &&
            sentence[n - 1] != '?' &&
            sentence[n - 1] != '!')
    {
        sentence += ".";
    }
#endif
    options.expr = sentence = expand_contractions(sentence);
    std::stringstream shared_info_messages;
    build_pos_paths_from_sentence(&all_paths_str,
                                   sentence,
                                   shared_info_messages);
    if(!options.quiet) {
        std::cerr << shared_info_messages.str();
    }
    std::stringstream shared_header, shared_footer;
    int path_index = 0;
    std::vector<job_context_t> all_jobs;
    for(std::list<std::vector<std::string>>::iterator p = all_paths_str.begin(); p != all_paths_str.end(); p++) {
        all_jobs.push_back(job_context_t(&options,
                                          pos_path_ast_tuple_t(*p, NULL, path_index),
                                         &shared_header,
                                         &shared_footer));
        path_index++;
    }
    if(options.serial) {
        {
            std::string msg = "Step 3/4. Parse POS-paths in Serial:";
            std::string bar = std::string(msg.length(), '=');
            std::cerr << std::endl << bar << std::endl << msg << std::endl << bar << std::endl << std::endl;
        }

        int path_index = 0;
        for(std::vector<job_context_t>::iterator p = all_jobs.begin(); p != all_jobs.end(); p++) {
            std::cerr << "INFO: Processing path #" << path_index << std::endl;
            do_job(&(*p));
            path_index++;
        }
    } else {
        {
            std::string msg = "Step 3/4. Parse POS-paths in Parallel:";
            std::string bar = std::string(msg.length(), '=');
            std::cerr << std::endl << bar << std::endl << msg << std::endl << bar << std::endl << std::endl;
        }

        size_t job_count = all_jobs.size();
        int batch_count = std::max(job_count, job_count - 1) / NTHREADS + 1;
        if(!options.quiet) {
            std::cerr << "INFO: Processing " << all_jobs.size() << " jobs in " << batch_count << " batches.." << std::endl;
        }
        int batch_index = 1;
        std::vector<job_context_t*> batch_jobs;
        for(std::vector<job_context_t>::iterator q = all_jobs.begin(); q != all_jobs.end(); q++) {
            batch_jobs.push_back(&(*q));
            if(batch_jobs.size() >= NTHREADS) {
                if(!options.quiet) {
                    std::cerr << "INFO: Processing batch " << batch_index << "/" << batch_count << " with " << batch_jobs.size() << " jobs.." << std::endl;
                }
                process_batch_jobs(batch_jobs);
                batch_jobs.clear();
                batch_index++;
            }
        }
        if(batch_jobs.size()) {
            if(!options.quiet) {
                std::cerr << "INFO: Processing batch " << batch_index << "/" << batch_count << " with " << batch_jobs.size() << " jobs.." << std::endl;
            }
            process_batch_jobs(batch_jobs);
            batch_jobs.clear();
            batch_index++;
        }
        if(!options.quiet) {
            std::cerr << "INFO: Successfully processed " << all_jobs.size() << " jobs in " << batch_count << " batches.." << std::endl;
        }
    }

    {
        std::string msg = "Step 4/4. Print ASTs:";
        std::string bar = std::string(msg.length(), '=');
        std::cerr << std::endl << bar << std::endl << msg << std::endl << bar << std::endl << std::endl;
    }

    int successful_parse_count = 0;
    std::cout << shared_header.str();
    for(std::vector<job_context_t>::iterator r = all_jobs.begin(); r != all_jobs.end(); r++) {
        if(!options.quiet) {
            std::cerr << (*r).m_info_messages.str();
            std::cerr << (*r).m_error_messages.str();
        }
        std::cout << (*r).m_output.str();
        if((*r).m_pos_path_ast_tuple.m_ast) {
            successful_parse_count++;
        }
    }
    std::cout << shared_footer.str();
    if(!successful_parse_count) {
        std::cerr << "Info: Parse fail!" << std::endl;
        return false;
    }
    std::cerr << "Info: Successful parse count: " << successful_parse_count << std::endl;
    return true;
}

int main(int argc, char** argv)
{
    options_t options;
    if(!extract_options_from_args(&options, argc, argv)) {
        display_usage(false);
        return EXIT_FAILURE;
    }
    if(!apply_options(options)) {
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
