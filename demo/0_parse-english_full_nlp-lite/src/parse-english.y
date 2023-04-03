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
        case ID_CLAUSE:            return "CLAUSE";
        //=================================================
        // NOUN PART -- VERB PART
        case ID_NP:                return "NP";
        case ID_VP:                return "VP";
        //=================================================
        // VERB
        case ID_V_NP:              return "V_NP";
        //=================================================
        // ADJECTIVE
        case ID_ADJ_N:             return "ADJ_N";
        //=================================================
        // LIST
        case ID_S_LIST:            return "S_LIST";
        case ID_CLAUSE_LIST:       return "CLAUSE_LIST";
        case ID_NP_LIST:           return "NP_LIST";
        case ID_VP_LIST:           return "VP_LIST";
        case ID_ADJ_LIST:          return "ADJ_LIST";
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
%type<symbol_value> S S_PUNC STMT CLAUSE
                    NP VP
                    V_NP
                    ADJ_N
                    S_LIST CLAUSE_LIST NP_LIST VP_LIST ADJ_LIST

// IDs for internal nodes
%nonassoc           ID_S ID_S_PUNC ID_STMT ID_CLAUSE
                    ID_NP ID_VP
                    ID_V_NP
                    ID_ADJ_N
                    ID_S_LIST ID_CLAUSE_LIST ID_NP_LIST ID_VP_LIST ID_ADJ_LIST

//=========
// TERMINAL
//=========

// IDs for terminals
%token<ident_value> ID_N ID_V ID_ADJ
                    ID_CONJ_CLAUSE ID_CONJ_NP ID_CONJ_VP
                    ID_PUNC

// rules for terminals
%type<symbol_value> N V ADJ
                    CONJ_CLAUSE CONJ_NP CONJ_VP
                    PUNC

%%

//==============
// INTERNAL NODE
//==============

root:
      S_LIST { pc->tree_context().root() = $1; YYACCEPT; }
    | error  { yyclearin; /* yyerrok; YYABORT; */ }
    ;

S_PUNC:
      S PUNC { $$ = MAKE_SYMBOL(ID_S_PUNC, 2, $1, $2); }
    ;

S:
      STMT { $$ = MAKE_SYMBOL(ID_S, 1, $1); }
    ;

STMT:
      CLAUSE_LIST { $$ = MAKE_SYMBOL(ID_STMT, 1, $1); }
    ;

CLAUSE:
      NP_LIST VP_LIST { $$ = MAKE_SYMBOL(ID_CLAUSE, 2, $1, $2); }
    ;

//=============================================================================
// NOUN PART -- VERB PART

NP:
      ADJ_N { $$ = MAKE_SYMBOL(ID_NP, 1, $1); }
    ;

VP:
      V_NP { $$ = MAKE_SYMBOL(ID_VP, 1, $1); }
    ;

//=============================================================================
// VERB

V_NP:
      V         { $$ = MAKE_SYMBOL(ID_V_NP, 1, $1); }
    | V NP_LIST { $$ = MAKE_SYMBOL(ID_V_NP, 2, $1, $2); }
    ;

//=============================================================================
// ADJECTIVE

ADJ_N:
               N { $$ = MAKE_SYMBOL(ID_ADJ_N, 1, $1); }
    | ADJ_LIST N { $$ = MAKE_SYMBOL(ID_ADJ_N, 2, $1, $2); }
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

NP_LIST:
                      NP { $$ = MAKE_SYMBOL(ID_NP_LIST, 1, $1); }
    | NP_LIST CONJ_NP NP { $$ = MAKE_SYMBOL(ID_NP_LIST, 3, $1, $2, $3); }
    ;

VP_LIST:
                      VP { $$ = MAKE_SYMBOL(ID_VP_LIST, 1, $1); }
    | VP_LIST CONJ_VP VP { $$ = MAKE_SYMBOL(ID_VP_LIST, 3, $1, $2, $3); }
    ;

ADJ_LIST:
               ADJ { $$ = MAKE_SYMBOL(ID_ADJ_LIST, 1, $1); }
    | ADJ_LIST ADJ { $$ = MAKE_SYMBOL(ID_ADJ_LIST, 2, $1, $2); }
    ;

//=========
// TERMINAL
//=========

//=============================================================================
// NOUN -- VERB -- ADJECTIVE

N:
      ID_N { $$ = MAKE_TERM(ID_N, $1); }
    ;

V:
      ID_V { $$ = MAKE_TERM(ID_V, $1); }
    ;

ADJ:
      ID_ADJ { $$ = MAKE_TERM(ID_ADJ, $1); }
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

 /*==========================================================================*/
 /* PUNC */

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
