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

#ifndef PARSE_ENGLISH_LEXER_ID_WRAPPER_H_
#define PARSE_ENGLISH_LEXER_ID_WRAPPER_H_

class ParserContext;
#ifndef YY_TYPEDEF_YY_SCANNER_T
#define YY_TYPEDEF_YY_SCANNER_T
    typedef void* yyscan_t;
#endif
#include "../../0_parse-english_full_nlp-lite/include/parse-english.tab.h" // YYLTYPE (generated)

#endif
