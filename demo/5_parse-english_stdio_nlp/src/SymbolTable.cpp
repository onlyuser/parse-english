#include "../../5_parse-english_stdio_nlp/include/SymbolTable.h"

#include <string>
#include <sstream>
#include <iostream>

Symbol::Symbol(type_t type, std::string name)
    : m_type(type),
      m_name(name)
{
}

void Symbol::print() const
{
    std::stringstream ss;
    ss << "\"" << m_name << "\"\t: ";
    switch(m_type) {
        case VAR: ss << "var"; break;
        default:
            break;
    }
    ss << std::endl;
    std::cout << ss.str();
}

SymbolTable::SymbolTable()
{
}

SymbolTable::~SymbolTable()
{
    reset();
}

SymbolTable* SymbolTable::instance()
{
    static SymbolTable g_symbol_table;
    return &g_symbol_table;
}

bool SymbolTable::add_symbol(std::string name, Symbol::type_t type)
{
    symbols_t::iterator p = m_symbols.find(name);
    if(p != m_symbols.end()) {
        std::cout << "Error: Name \"" << name << "\" already exists in symbol table!" << std::endl;
        return false;
    }
    m_symbols.insert(p, symbols_t::value_type(name, new Symbol(type, name)));
    return true;
}

bool SymbolTable::lookup_symbol(std::string name, Symbol::type_t *type)
{
    symbols_t::iterator p = m_symbols.find(name);
    if(p == m_symbols.end()) {
        std::cout << "Error: Name \"" << name << "\" doesn't exist in symbol table!" << std::endl;
        return false;
    }
    if(type) {
        *type = (*p).second->type();
    }
    return true;
}

bool SymbolTable::lookup_symbol_by_type(std::string name, Symbol::type_t type)
{
    for(symbols_t::iterator p = m_symbols.begin(); p != m_symbols.end(); p++) {
        if((*p).first == name && (*p).second && type == (*p).second->type()) {
            return true;
        }
    }
    std::cout << "Error: Name \"" << name << "\" doesn't exist in symbol table!" << std::endl;
    return false;
}

void SymbolTable::print() const
{
    std::cout << "Symbol table:" << std::endl;
    std::cout << "[name]\t: [meta-type]" << std::endl;
    for(symbols_t::const_iterator p = m_symbols.begin(); p != m_symbols.end(); p++) {
        if((*p).second) {
            (*p).second->print();
        }
    }
}

void SymbolTable::reset()
{
    for(symbols_t::iterator p = m_symbols.begin(); p != m_symbols.end(); p++) {
        if((*p).second) {
            delete (*p).second;
        }
    }
    m_symbols.clear();
}
