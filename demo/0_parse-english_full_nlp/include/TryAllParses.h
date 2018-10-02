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

#ifndef TRY_ALL_PARSES_H_
#define TRY_ALL_PARSES_H_

#include "node/XLangNodeIFace.h" // node::NodeIdentIFace
#include "XLangAlloc.h" // Allocator
#include <vector> // std::vector
#include <list> // std::list
#include <stack> // std::stack
#include <string> // std::string

bool get_pos_options(std::string               word,
                     std::vector<std::string>* pos_options);
void build_all_paths_from_pos_options(std::list<std::vector<int> >*                 all_paths,          // OUT
                                      const std::vector<std::vector<std::string> > &pos_table,          // IN
                                      std::vector<int>*                             path_so_far = NULL, // TEMP
                                      int                                           word_index  = 0);   // TEMP
void build_pos_paths_from_sentence(std::list<std::vector<std::string> >* all_paths_str, // OUT
                                   std::string                           sentence);     // IN

#endif
