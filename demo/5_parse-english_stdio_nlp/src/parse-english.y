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
#include "XLangType.h" // uint32_t
#include "SymbolTable.h" // SymbolTable
#include <stdio.h> // size_t
#include <stdarg.h> // va_start
#include <string> // std::string
#include <sstream> // std::stringstream
#include <iostream> // std::cout
#include <stdlib.h> // EXIT_SUCCESS
#include <getopt.h> // getopt_long

#define MAKE_TERM(lexer_id, ...)   xl::mvc::MVCModel::make_term(tree_context(), lexer_id, ##__VA_ARGS__)
#define MAKE_SYMBOL(...)           xl::mvc::MVCModel::make_symbol(tree_context(), ##__VA_ARGS__)
#define ERROR_LEXER_ID_NOT_FOUND   "missing lexer id handler, most likely you forgot to register one"
#define ERROR_LEXER_NAME_NOT_FOUND "missing lexer name handler, most likely you forgot to register one"

std::stringstream _error_messages;

// report error
void yyerror(const char* s)
{
    _error_messages << s;
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
    if(name == "int")   return ID_INT;
    if(name == "float") return ID_FLOAT;
    if(name == "ident") return ID_IDENT;
    throw ERROR_LEXER_NAME_NOT_FOUND;
    return 0;
}

xl::TreeContext* &tree_context()
{
    static xl::TreeContext* tc = NULL;
    return tc;
}

%}

// type of yylval to be set by scanner actions
// implemented as %union in non-reentrant mode
%union
{
    xl::node::TermInternalType<xl::node::NodeIdentIFace::INT>::type    int_value;    // int value
    xl::node::TermInternalType<xl::node::NodeIdentIFace::FLOAT>::type  float_value;  // float value
    xl::node::TermInternalType<xl::node::NodeIdentIFace::IDENT>::type  ident_value;  // symbol table index
    xl::node::TermInternalType<xl::node::NodeIdentIFace::SYMBOL>::type symbol_value; // node pointer
}

// show detailed parse errors
%error-verbose

%nonassoc ID_BASE

%token<int_value>   ID_INT
%token<float_value> ID_FLOAT
%token<ident_value> ID_IDENT

//==============
// INTERNAL NODE
//==============

// rules for internal nodes
%type<symbol_value> S S_PUNC STMT QUERY COND CMD CLAUSE QCLAUSE
                    NP POSS VP QVP CVP
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
                    ID_NP ID_POSS ID_VP ID_QVP ID_CVP
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
%token<ident_value> ID_N ID_V ID_VPAST ID_VGERUND ID_VPASTPERF ID_V_MOD_INFIN ID_ADJ ID_ADV_MOD_ADJ ID_ADV_MOD_V ID_ADV_MOD_VGERUND_PRE ID_ADV_MOD_VGERUND_POST ID_PREP
                    ID_DEM ID_ART_OR_PREFIXPOSS ID_SUFFIXPOSS
                    ID_BEING ID_BEEN
                    ID_BE ID_CBE ID_HAVE ID_MODAL ID_DO ID_TO_MOD_V
                    ID_CONJ_CLAUSE ID_CONJ_NP ID_CONJ_VP ID_CONJ_ADJ ID_CONJ_PREP
                    ID_WHWORD ID_WHWORD_MOD_THAT
                    ID_IF ID_THEN ID_BECAUSE
                    ID_NOT ID_FREQ ID_FREQ_EOS ID_TOO ID_PUNC

// rules for terminals
%type<symbol_value> N V VPAST VGERUND VPASTPERF V_MOD_INFIN ADJ ADV_MOD_ADJ ADV_MOD_V ADV_MOD_VGERUND_PRE ADV_MOD_VGERUND_POST PREP
                    DEM ART_OR_PREFIXPOSS SUFFIXPOSS
                    BEING BEEN
                    BE CBE HAVE MODAL DO TO_MOD_V
                    CONJ_CLAUSE CONJ_NP CONJ_VP CONJ_ADJ CONJ_PREP
                    WHWORD WHWORD_MOD_THAT
                    IF THEN BECAUSE
                    NOT FREQ FREQ_EOS TOO PUNC

%%

//==============
// INTERNAL NODE
//==============

root:
      S_LIST { tree_context()->root() = $1; YYACCEPT; }
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
      IF      CLAUSE_LIST THEN        CLAUSE_LIST { $$ = MAKE_SYMBOL(ID_COND, 2, $2, $4); }
    |         CLAUSE_LIST IF          CLAUSE_LIST { $$ = MAKE_SYMBOL(ID_COND, 2, $1, $3); }
    | BECAUSE CLAUSE_LIST CONJ_CLAUSE CLAUSE_LIST { $$ = MAKE_SYMBOL(ID_COND, 2, $2, $4); }
    |         CLAUSE_LIST BECAUSE     CLAUSE_LIST { $$ = MAKE_SYMBOL(ID_COND, 2, $1, $3); }
    |         AUX_NP_V    CONJ_CLAUSE CLAUSE_LIST { $$ = MAKE_SYMBOL(ID_COND, 2, $1, $3); }
    ;

CMD:
      CVP_LIST { $$ = MAKE_SYMBOL(ID_CMD, 1, $1); }
    ;

CLAUSE:
      NP_LIST VP_LIST { $$ = MAKE_SYMBOL(ID_CLAUSE, 2, $1, $2); }
    | PREP_LIST       { $$ = MAKE_SYMBOL(ID_CLAUSE, 1, $1); }
    ;

QCLAUSE:
             QVP { $$ = MAKE_SYMBOL(ID_QCLAUSE, 1, $1); }
    | WHWORD QVP { $$ = MAKE_SYMBOL(ID_QCLAUSE, 2, $1, $2); }
    ;

//=============================================================================
// NOUN PART -- VERB PART

NP:
      POSS           { $$ = MAKE_SYMBOL(ID_NP, 1, $1); }
    | ADV_VGERUND_NP { $$ = MAKE_SYMBOL(ID_NP, 1, $1); }
    | INFIN          { $$ = MAKE_SYMBOL(ID_NP, 1, $1); }
    | WHPRON VP      { $$ = MAKE_SYMBOL(ID_NP, 2, $1, $2); }
    | PREP_LIST      { $$ = MAKE_SYMBOL(ID_NP, 1, $1); }
    ;

POSS:
      DET_ADJ_N                      { $$ = MAKE_SYMBOL(ID_POSS, 1, $1); }
    | DET_ADJ_N SUFFIXPOSS POSS_LIST { $$ = MAKE_SYMBOL(ID_POSS, 3, $1, $2, $3); }
    |                      POSS_LIST { $$ = MAKE_SYMBOL(ID_POSS, 1, $1); }
    ;

VP:
        AUX_NOT_V                      { $$ = MAKE_SYMBOL(ID_VP, 1, $1); }
    | MODAL_NOT_OR_FREQ   MODAL_TARGET { $$ = MAKE_SYMBOL(ID_VP, 2, $1, $2); }
    |    DO_NOT_OR_FREQ      DO_TARGET { $$ = MAKE_SYMBOL(ID_VP, 2, $1, $2); }
    |                   FREQ_DO_TARGET { $$ = MAKE_SYMBOL(ID_VP, 1, $1); }
    |                     ADV_VPAST_NP { $$ = MAKE_SYMBOL(ID_VP, 1, $1); }
    ;

QVP:
        AUX_NP_V              { $$ = MAKE_SYMBOL(ID_QVP, 1, $1); }
    | MODAL_NP   MODAL_TARGET { $$ = MAKE_SYMBOL(ID_QVP, 2, $1, $2); }
    |    DO_NP      DO_TARGET { $$ = MAKE_SYMBOL(ID_QVP, 2, $1, $2); }
    ;

CVP:
      CAUX_V                        { $$ = MAKE_SYMBOL(ID_CVP, 1, $1); }
    | DO_NOT_OR_FREQ      DO_TARGET { $$ = MAKE_SYMBOL(ID_CVP, 2, $1, $2); }
    |                FREQ_DO_TARGET { $$ = MAKE_SYMBOL(ID_CVP, 1, $1); }
    ;

//=============================================================================
// AUXILIARY VERB

AUX_V:
           BE     OPT_BE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_V, 2, $1, $2); }
    | HAVE BEEN   OPT_BE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_V, 3, $1, $2, $3); }
    | HAVE      ADV_HAVE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_V, 2, $1, $2); }
    ;

CAUX_V:
      CBE OPT_BE_TARGET { $$ = MAKE_SYMBOL(ID_CAUX_V, 2, $1, $2); }
    ;

AUX_NOT_V:
                       BE_NOT_OR_FREQ   OPT_BE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_NOT_V, 2, $1, $2); }
    | HAVE_NOT_OR_FREQ BEEN             OPT_BE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_NOT_V, 3, $1, $2, $3); }
    | HAVE_NOT_OR_FREQ                ADV_HAVE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_NOT_V, 2, $1, $2); }
    ;

AUX_NP_V:
              BE_NP   OPT_BE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_NP_V, 2, $1, $2); }
    | HAVE_NP BEEN    OPT_BE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_NP_V, 3, $1, $2, $3); }
    | HAVE_NP       ADV_HAVE_TARGET { $$ = MAKE_SYMBOL(ID_AUX_NP_V, 2, $1, $2); }
    ;

//=============================================================================
// VERB

V_NP:
      V         { $$ = MAKE_SYMBOL(ID_V_NP, 1, $1); }
    | V NP_LIST { $$ = MAKE_SYMBOL(ID_V_NP, 2, $1, $2); }
    ;

VPAST_NP:
      VPAST         { $$ = MAKE_SYMBOL(ID_VPAST_NP, 1, $1); }
    | VPAST NP_LIST { $$ = MAKE_SYMBOL(ID_VPAST_NP, 2, $1, $2); }
    ;

VGERUND_NP:
      VGERUND               { $$ = MAKE_SYMBOL(ID_VGERUND_NP, 1, $1); }
    | VGERUND NP_LIST       { $$ = MAKE_SYMBOL(ID_VGERUND_NP, 2, $1, $2); }
    | BEING   OPT_BE_TARGET { $$ = MAKE_SYMBOL(ID_VGERUND_NP, 2, $1, $2); }
    ;

PREP_NP:
      PREP NP_LIST { $$ = MAKE_SYMBOL(ID_PREP_NP, 2, $1, $2); } // NOTE: using NP_LIST here causes shift-reduce conflict because NP ==> PREP_NP ==> NP
                                                                //       however, not having NP_LIST here makes parsing "from here and there.." impossible
    ;

//=============================================================================
// TARGET (BE -- HAVE -- MODAL -- DO)

BE_TARGET:
      ADV_HAVE_TARGET { $$ = MAKE_SYMBOL(ID_BE_TARGET, 1, $1); }
    | NP_LIST         { $$ = MAKE_SYMBOL(ID_BE_TARGET, 1, $1); }
    | ADJ_LIST        { $$ = MAKE_SYMBOL(ID_BE_TARGET, 1, $1); }
    ;

HAVE_TARGET:
      VPASTPERF         { $$ = MAKE_SYMBOL(ID_HAVE_TARGET, 1, $1); }
    | VPASTPERF NP_LIST { $$ = MAKE_SYMBOL(ID_HAVE_TARGET, 2, $1, $2); }
    ;

MODAL_TARGET:
      DO_TARGET { $$ = MAKE_SYMBOL(ID_MODAL_TARGET, 1, $1); }
    | AUX_V     { $$ = MAKE_SYMBOL(ID_MODAL_TARGET, 1, $1); }
    ;

DO_TARGET:
      ADV_V_NP { $$ = MAKE_SYMBOL(ID_DO_TARGET, 1, $1); }
    | V_INFIN  { $$ = MAKE_SYMBOL(ID_DO_TARGET, 1, $1); }
    ;

OPT_BE_TARGET:
      /* empty */ { $$ = xl::node::SymbolNode::eol(); }
    | BE_TARGET   { $$ = MAKE_SYMBOL(ID_OPT_BE_TARGET, 1, $1); }
    ;

FREQ_DO_TARGET:
           DO_TARGET { $$ = MAKE_SYMBOL(ID_FREQ_DO_TARGET, 1, $1); }
    | FREQ DO_TARGET { $$ = MAKE_SYMBOL(ID_FREQ_DO_TARGET, 2, $1, $2); }
    ;

//=============================================================================
// VERB (ADVERB)

ADV_V_NP:
                V_NP           { $$ = MAKE_SYMBOL(ID_ADV_V_NP, 1, $1); }
    | ADV_MOD_V V_NP           { $$ = MAKE_SYMBOL(ID_ADV_V_NP, 2, $1, $2); }
    |           V_NP ADV_MOD_V { $$ = MAKE_SYMBOL(ID_ADV_V_NP, 2, $1, $2); }
    ;

ADV_VPAST_NP:
                VPAST_NP           { $$ = MAKE_SYMBOL(ID_ADV_VPAST_NP, 1, $1); }
    | ADV_MOD_V VPAST_NP           { $$ = MAKE_SYMBOL(ID_ADV_VPAST_NP, 2, $1, $2); }
    |           VPAST_NP ADV_MOD_V { $$ = MAKE_SYMBOL(ID_ADV_VPAST_NP, 2, $1, $2); }
    ;

ADV_VGERUND_NP:
                          VGERUND_NP                      { $$ = MAKE_SYMBOL(ID_ADV_VGERUND_NP, 1, $1); }
    | ADV_MOD_VGERUND_PRE VGERUND_NP                      { $$ = MAKE_SYMBOL(ID_ADV_VGERUND_NP, 2, $1, $2); }
    |                     VGERUND_NP ADV_MOD_VGERUND_POST { $$ = MAKE_SYMBOL(ID_ADV_VGERUND_NP, 2, $1, $2); }
    ;

ADV_HAVE_TARGET:
                HAVE_TARGET           { $$ = MAKE_SYMBOL(ID_ADV_HAVE_TARGET, 1, $1); }
    | ADV_MOD_V HAVE_TARGET           { $$ = MAKE_SYMBOL(ID_ADV_HAVE_TARGET, 2, $1, $2); }
    |           HAVE_TARGET ADV_MOD_V { $$ = MAKE_SYMBOL(ID_ADV_HAVE_TARGET, 2, $1, $2); }
    ;

//=============================================================================
// INFINITIVE

INFIN:
      TO_NOT_OR_FREQ MODAL_TARGET { $$ = MAKE_SYMBOL(ID_INFIN, 2, $1, $2); }
    ;

V_INFIN:
      V_MOD_INFIN INFIN { $$ = MAKE_SYMBOL(ID_V_INFIN, 2, $1, $2); }
    ;

//=============================================================================
// ADJECTIVE -- ADVERB

ADJ_N:
               N { $$ = MAKE_SYMBOL(ID_ADJ_N, 1, $1); }
    | ADJ_LIST N { $$ = MAKE_SYMBOL(ID_ADJ_N, 2, $1, $2); }
    ;

ADV_ADJ:
                  ADJ { $$ = MAKE_SYMBOL(ID_ADV_ADJ, 1, $1); }
    | ADV_MOD_ADJ ADJ { $$ = MAKE_SYMBOL(ID_ADV_ADJ, 2, $1, $2); }
    ;

//=============================================================================
// DEMONSTRATIVE -- ARTICLE/PREFIX-POSSESSIVE

DET_ADJ_N:
      DEM                     { $$ = MAKE_SYMBOL(ID_DET_ADJ_N, 1, $1); }
    | DEM               ADJ_N { $$ = MAKE_SYMBOL(ID_DET_ADJ_N, 2, $1, $2); }
    | ART_OR_PREFIXPOSS ADJ_N { $$ = MAKE_SYMBOL(ID_DET_ADJ_N, 2, $1, $2); }
    ;

//=============================================================================
// BE -- HAVE -- MODAL -- DO (NOT)

BE_NOT:
      BE     { $$ = MAKE_SYMBOL(ID_BE_NOT, 1, $1); }
    | BE NOT { $$ = MAKE_SYMBOL(ID_BE_NOT, 2, $1, $2); }
    ;

HAVE_NOT:
      HAVE     { $$ = MAKE_SYMBOL(ID_HAVE_NOT, 1, $1); }
    | HAVE NOT { $$ = MAKE_SYMBOL(ID_HAVE_NOT, 2, $1, $2); }
    ;

MODAL_NOT:
      MODAL     { $$ = MAKE_SYMBOL(ID_MODAL_NOT, 1, $1); }
    | MODAL NOT { $$ = MAKE_SYMBOL(ID_MODAL_NOT, 2, $1, $2); }
    ;

DO_NOT:
      DO     { $$ = MAKE_SYMBOL(ID_DO_NOT, 1, $1); }
    | DO NOT { $$ = MAKE_SYMBOL(ID_DO_NOT, 2, $1, $2); }
    ;

//=============================================================================
// BE -- HAVE -- MODAL -- DO (NOT NOUN FREQ)

BE_NP:
      BE_NOT NP_LIST      { $$ = MAKE_SYMBOL(ID_BE_NP, 2, $1, $2); }
    | BE_NOT NP_LIST FREQ { $$ = MAKE_SYMBOL(ID_BE_NP, 3, $1, $2, $3); }
    ;

HAVE_NP:
      HAVE_NOT NP_LIST      { $$ = MAKE_SYMBOL(ID_HAVE_NP, 2, $1, $2); }
    | HAVE_NOT NP_LIST FREQ { $$ = MAKE_SYMBOL(ID_HAVE_NP, 3, $1, $2, $3); }
    ;

MODAL_NP:
      MODAL_NOT NP_LIST      { $$ = MAKE_SYMBOL(ID_MODAL_NP, 2, $1, $2); }
    | MODAL_NOT NP_LIST FREQ { $$ = MAKE_SYMBOL(ID_MODAL_NP, 3, $1, $2, $3); }
    ;

DO_NP:
      DO_NOT NP_LIST      { $$ = MAKE_SYMBOL(ID_DO_NP, 2, $1, $2); }
    | DO_NOT NP_LIST FREQ { $$ = MAKE_SYMBOL(ID_DO_NP, 3, $1, $2, $3); }
    ;

//=============================================================================
// BE -- HAVE -- MODAL -- DO -- TO (NOT OR FREQ)

BE_NOT_OR_FREQ:
      BE             { $$ = MAKE_SYMBOL(ID_BE_NOT_OR_FREQ, 1, $1); }
    | BE NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_BE_NOT_OR_FREQ, 2, $1, $2); }
    ;

HAVE_NOT_OR_FREQ:
      HAVE             { $$ = MAKE_SYMBOL(ID_HAVE_NOT_OR_FREQ, 1, $1); }
    | HAVE NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_HAVE_NOT_OR_FREQ, 2, $1, $2); }
    ;

MODAL_NOT_OR_FREQ:
      MODAL             { $$ = MAKE_SYMBOL(ID_MODAL_NOT_OR_FREQ, 1, $1); }
    | MODAL NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_MODAL_NOT_OR_FREQ, 2, $1, $2); }
    ;

DO_NOT_OR_FREQ:
      DO             { $$ = MAKE_SYMBOL(ID_DO_NOT_OR_FREQ, 1, $1); }
    | DO NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_DO_NOT_OR_FREQ, 2, $1, $2); }
    ;

TO_NOT_OR_FREQ:
      TO_MOD_V             { $$ = MAKE_SYMBOL(ID_TO_NOT_OR_FREQ, 1, $1); }
    | TO_MOD_V NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_TO_NOT_OR_FREQ, 2, $1, $2); }
    ;

//=============================================================================
// LIST

S_LIST:
             S_PUNC { $$ = MAKE_SYMBOL(ID_S_LIST, 1, $1); }
    | S_LIST S_PUNC { $$ = MAKE_SYMBOL(ID_S_LIST, 2, $1, $2); }
    ;

CLAUSE_LIST:
                              CLAUSE { $$ = MAKE_SYMBOL(ID_CLAUSE_LIST, 1, $1); }
    | CLAUSE_LIST             CLAUSE { $$ = MAKE_SYMBOL(ID_CLAUSE_LIST, 2, $1, $2); }
    | CLAUSE_LIST CONJ_CLAUSE CLAUSE { $$ = MAKE_SYMBOL(ID_CLAUSE_LIST, 3, $1, $2, $3); }
    ;

QCLAUSE_LIST:
                               QCLAUSE { $$ = MAKE_SYMBOL(ID_QCLAUSE_LIST, 1, $1); }
    | QCLAUSE_LIST             QCLAUSE { $$ = MAKE_SYMBOL(ID_QCLAUSE_LIST, 2, $1, $2); }
    | QCLAUSE_LIST CONJ_CLAUSE QCLAUSE { $$ = MAKE_SYMBOL(ID_QCLAUSE_LIST, 3, $1, $2, $3); }
    ;

CVP_LIST:
                           CVP { $$ = MAKE_SYMBOL(ID_CVP_LIST, 1, $1); }
    | CVP_LIST             CVP { $$ = MAKE_SYMBOL(ID_CVP_LIST, 2, $1, $2); }
    | CVP_LIST CONJ_CLAUSE CVP { $$ = MAKE_SYMBOL(ID_CVP_LIST, 3, $1, $2, $3); }
    ;

NP_LIST:
                          NP { $$ = MAKE_SYMBOL(ID_NP_LIST, 1, $1); }
    | NP_LIST             NP { $$ = MAKE_SYMBOL(ID_NP_LIST, 2, $1, $2); }
    | NP_LIST CONJ_NP_NOT NP { $$ = MAKE_SYMBOL(ID_NP_LIST, 3, $1, $2, $3); }
    ;

VP_LIST:
                          VP { $$ = MAKE_SYMBOL(ID_VP_LIST, 1, $1); }
    | VP_LIST             VP { $$ = MAKE_SYMBOL(ID_VP_LIST, 2, $1, $2); }
    | VP_LIST CONJ_VP_NOT VP { $$ = MAKE_SYMBOL(ID_VP_LIST, 3, $1, $2, $3); }
    ;

ADJ_LIST:
                            ADV_ADJ { $$ = MAKE_SYMBOL(ID_ADJ_LIST, 1, $1); }
    | ADJ_LIST              ADV_ADJ { $$ = MAKE_SYMBOL(ID_ADJ_LIST, 2, $1, $2); }
    | ADJ_LIST CONJ_ADJ_NOT ADV_ADJ { $$ = MAKE_SYMBOL(ID_ADJ_LIST, 3, $1, $2, $3); }
    ;

PREP_LIST:
                              PREP_NP { $$ = MAKE_SYMBOL(ID_PREP_LIST, 1, $1); }
    | PREP_LIST               PREP_NP { $$ = MAKE_SYMBOL(ID_PREP_LIST, 2, $1, $2); }
    | PREP_LIST CONJ_PREP_NOT PREP_NP { $$ = MAKE_SYMBOL(ID_PREP_LIST, 3, $1, $2, $3); }
    ;

POSS_LIST:
                           ADJ_N { $$ = MAKE_SYMBOL(ID_POSS_LIST, 1, $1); }
    | POSS_LIST SUFFIXPOSS ADJ_N { $$ = MAKE_SYMBOL(ID_POSS_LIST, 3, $1, $2, $3); }
    ;

//=============================================================================
// CONJUGATION

CONJ_NP_NOT:
      CONJ_NP             { $$ = MAKE_SYMBOL(ID_CONJ_NP_NOT, 1, $1); }
    | CONJ_NP NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_CONJ_NP_NOT, 2, $1, $2); }
    ;

CONJ_VP_NOT:
      CONJ_VP             { $$ = MAKE_SYMBOL(ID_CONJ_VP_NOT, 1, $1); }
    | CONJ_VP NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_CONJ_VP_NOT, 2, $1, $2); }
    ;

CONJ_ADJ_NOT:
      CONJ_ADJ             { $$ = MAKE_SYMBOL(ID_CONJ_ADJ_NOT, 1, $1); }
    | CONJ_ADJ NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_CONJ_ADJ_NOT, 2, $1, $2); }
    ;

CONJ_PREP_NOT:
      CONJ_PREP             { $$ = MAKE_SYMBOL(ID_CONJ_PREP_NOT, 1, $1); }
    | CONJ_PREP NOT_OR_FREQ { $$ = MAKE_SYMBOL(ID_CONJ_PREP_NOT, 2, $1, $2); }
    ;

//=============================================================================
// WH-PRONOUN

WHPRON:
      WHWORD          { $$ = MAKE_SYMBOL(ID_WHPRON, 1, $1); }
    | WHWORD_MOD_THAT { $$ = MAKE_SYMBOL(ID_WHPRON, 1, $1); }
    ;

//=============================================================================
 /* NOT-OR-FREQ -- EOS */

NOT_OR_FREQ:
      NOT      { $$ = MAKE_SYMBOL(ID_NOT_OR_FREQ, 1, $1); }
    | NOT FREQ { $$ = MAKE_SYMBOL(ID_NOT_OR_FREQ, 2, $1, $2); }
    |     FREQ { $$ = MAKE_SYMBOL(ID_NOT_OR_FREQ, 1, $1); }
    ;

EOS:
      TOO      { $$ = MAKE_SYMBOL(ID_EOS, 1, $1); }
    | FREQ_EOS { $$ = MAKE_SYMBOL(ID_EOS, 1, $1); }
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
      ID_WHWORD { $$ = MAKE_TERM(ID_WHWORD, $1); }
    ;

WHWORD_MOD_THAT:
      ID_WHWORD_MOD_THAT { $$ = MAKE_TERM(ID_WHWORD_MOD_THAT, $1); }
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

xl::node::NodeIdentIFace* make_ast(xl::Allocator &alloc)
{
    tree_context() = new (PNEW(alloc, xl::, TreeContext)) xl::TreeContext(alloc);
    int error_code = yyparse(); // parser entry point
    yylex_destroy(); // NOTE: necessary to avoid memory leak
    return (!error_code && _error_messages.str().empty()) ? tree_context()->root() : NULL;
}

void display_usage(bool verbose)
{
    std::cout << "Usage: parse-english [-i] OPTION [-m]" << std::endl;
    if(verbose) {
        std::cout << "Parses input and prints a syntax tree to standard out" << std::endl
                  << std::endl
                  << "Input control:" << std::endl
                  << "  -i, --in-xml FILENAME (de-serialize from xml)" << std::endl
                  << std::endl
                  << "Output control:" << std::endl
                  << "  -l, --lisp" << std::endl
                  << "  -x, --xml" << std::endl
                  << "  -g, --graph" << std::endl
                  << "  -d, --dot" << std::endl
                  << "  -m, --memory" << std::endl
                  << "  -h, --help" << std::endl;
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
        MODE_XML,
        MODE_GRAPH,
        MODE_DOT,
        MODE_HELP
    } mode_e;

    mode_e      mode;
    std::string in_xml;
    bool        dump_memory;
    bool        indent;

    options_t()
        : mode(MODE_NONE), dump_memory(false), indent(false)
    {}
};

bool extract_options_from_args(options_t* options, int argc, char** argv)
{
    if(!options)
        return false;
    int opt = 0;
    int longIndex = 0;
    static const char *optString = "i:lxgdmnh?";
    static const struct option longOpts[] = { { "in-xml", required_argument, NULL, 'i' },
                                              { "lisp",   no_argument,       NULL, 'l' },
                                              { "xml",    no_argument,       NULL, 'x' },
                                              { "graph",  no_argument,       NULL, 'g' },
                                              { "dot",    no_argument,       NULL, 'd' },
                                              { "memory", no_argument,       NULL, 'm' },
                                              { "indent", no_argument,       NULL, 'n' },
                                              { "help",   no_argument,       NULL, 'h' },
                                              { NULL,     no_argument,       NULL, 0   } };
    opt = getopt_long(argc, argv, optString, longOpts, &longIndex);
    while(opt != -1) {
        switch(opt) {
            case 'i': options->in_xml = optarg; break;
            case 'l': options->mode = options_t::MODE_LISP; break;
            case 'x': options->mode = options_t::MODE_XML; break;
            case 'g': options->mode = options_t::MODE_GRAPH; break;
            case 'd': options->mode = options_t::MODE_DOT; break;
            case 'm': options->dump_memory = true; break;
            case 'n': options->indent = true; break;
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

bool import_ast(options_t &options, xl::Allocator &alloc, xl::node::NodeIdentIFace* &ast)
{
    if(options.in_xml.size()) {
        ast = xl::mvc::MVCModel::make_ast(new (PNEW(alloc, xl::, TreeContext)) xl::TreeContext(alloc), options.in_xml);
        if(!ast) {
            std::cerr << "ERROR: de-serialize from xml fail!" << std::endl;
            return false;
        }
    } else {
        ast = make_ast(alloc);
        if(!ast) {
            std::cerr << "ERROR: " << _error_messages.str().c_str() << std::endl;
            return false;
        }
    }
    return true;
}

void export_ast(options_t &options, const xl::node::NodeIdentIFace* ast)
{
    std::string output;
    switch(options.mode) {
        case options_t::MODE_LISP:  output = xl::mvc::MVCView::print_lisp(ast, options.indent); break;
        case options_t::MODE_XML:   output = xl::mvc::MVCView::print_xml(ast); break;
        case options_t::MODE_GRAPH: output = xl::mvc::MVCView::print_graph(ast); break;
        case options_t::MODE_DOT:   output = xl::mvc::MVCView::print_dot(ast, true); break;
        default:
            break;
    }
    std::cout << output;
}

bool apply_options(options_t &options)
{
    try {
        if(options.mode == options_t::MODE_HELP) {
            display_usage(true);
            return true;
        }
        xl::Allocator alloc(__FILE__);
        xl::node::NodeIdentIFace* ast = NULL;
        if(!import_ast(options, alloc, ast)) {
            return false;
        }
        export_ast(options, ast);
        if(options.dump_memory) {
            alloc.dump(std::string(1, '\t'));
        }
    } catch(const char* s) {
        std::cerr << "ERROR: " << s << std::endl;
        return false;
    }
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
