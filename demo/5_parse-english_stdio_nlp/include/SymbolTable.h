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

#ifndef SYMBOL_TABLE_H_
#define SYMBOL_TABLE_H_

#include <map>
#include <string>

class Symbol
{
public:
    typedef enum { VAR } type_t;

    Symbol(type_t type, std::string name);
    type_t type() const      { return m_type; }
    std::string name() const { return m_name; }
    void print() const;

private:
    type_t      m_type;
    std::string m_name;
};

class SymbolTable
{
public:
    ~SymbolTable();
    static SymbolTable* instance();
    bool add_symbol(std::string name, Symbol::type_t type);
    bool lookup_symbol(std::string name, Symbol::type_t *type = NULL);
    bool lookup_symbol_by_type(std::string name, Symbol::type_t type);
    void print() const;
    void reset();

private:
    typedef std::map<std::string, Symbol*> symbols_t;
    symbols_t m_symbols;

    SymbolTable();
};

#endif
