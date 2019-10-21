// XLang
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

#include "visitor/XLangPrinter.h" // visitor::LispPrinter
#include "XLangString.h" // xl::escape
#include <sstream> // std::stringstream

//#define INCLUDE_NODE_UID

namespace xl { namespace visitor {

void TreeAnnotator::visit(const node::SymbolNodeIFace* _node)
{
    m_depth++;
    VisitorDFS::visit(_node);
    m_depth--;
    int max_height = 0;
    for(int i = 0; i < static_cast<int>(_node->size()); i++) {
        const node::NodeIdentIFace* child = (*_node)[i];
        if(child->height() > max_height) {
            max_height = child->height();
        }
    }
    const_cast<node::SymbolNodeIFace*>(_node)->set_height(max_height + 1);
    const_cast<node::SymbolNodeIFace*>(_node)->set_depth(m_depth);
}

void TreeAnnotator::visit(const node::TermNodeIFace<node::NodeIdentIFace::INT>* _node)
{
    const_cast<node::TermNodeIFace<node::NodeIdentIFace::INT>*>(_node)->set_height(0);
    const_cast<node::TermNodeIFace<node::NodeIdentIFace::INT>*>(_node)->set_depth(m_depth);
}

void TreeAnnotator::visit(const node::TermNodeIFace<node::NodeIdentIFace::FLOAT>* _node)
{
    const_cast<node::TermNodeIFace<node::NodeIdentIFace::FLOAT>*>(_node)->set_height(0);
    const_cast<node::TermNodeIFace<node::NodeIdentIFace::FLOAT>*>(_node)->set_depth(m_depth);
}

void TreeAnnotator::visit(const node::TermNodeIFace<node::NodeIdentIFace::STRING>* _node)
{
    const_cast<node::TermNodeIFace<node::NodeIdentIFace::STRING>*>(_node)->set_height(0);
    const_cast<node::TermNodeIFace<node::NodeIdentIFace::STRING>*>(_node)->set_depth(m_depth);
}

void TreeAnnotator::visit(const node::TermNodeIFace<node::NodeIdentIFace::CHAR>* _node)
{
    const_cast<node::TermNodeIFace<node::NodeIdentIFace::CHAR>*>(_node)->set_height(0);
    const_cast<node::TermNodeIFace<node::NodeIdentIFace::CHAR>*>(_node)->set_depth(m_depth);
}

void TreeAnnotator::visit(const node::TermNodeIFace<node::NodeIdentIFace::IDENT>* _node)
{
    const_cast<node::TermNodeIFace<node::NodeIdentIFace::IDENT>*>(_node)->set_height(0);
    const_cast<node::TermNodeIFace<node::NodeIdentIFace::IDENT>*>(_node)->set_depth(m_depth);
}

void TreeAnnotator::visit_null()
{
}

void TreeAnnotatorBFS::visit(const node::SymbolNodeIFace* _node)
{
    const_cast<node::SymbolNodeIFace*>(_node)->set_bfs_index(m_bfs_index++);
}

void TreeAnnotatorBFS::visit(const node::TermNodeIFace<node::NodeIdentIFace::INT>* _node)
{
    const_cast<node::TermNodeIFace<node::NodeIdentIFace::INT>*>(_node)->set_bfs_index(m_bfs_index++);
}

void TreeAnnotatorBFS::visit(const node::TermNodeIFace<node::NodeIdentIFace::FLOAT>* _node)
{
    const_cast<node::TermNodeIFace<node::NodeIdentIFace::FLOAT>*>(_node)->set_bfs_index(m_bfs_index++);
}

void TreeAnnotatorBFS::visit(const node::TermNodeIFace<node::NodeIdentIFace::STRING>* _node)
{
    const_cast<node::TermNodeIFace<node::NodeIdentIFace::STRING>*>(_node)->set_bfs_index(m_bfs_index++);
}

void TreeAnnotatorBFS::visit(const node::TermNodeIFace<node::NodeIdentIFace::CHAR>* _node)
{
    const_cast<node::TermNodeIFace<node::NodeIdentIFace::CHAR>*>(_node)->set_bfs_index(m_bfs_index++);
}

void TreeAnnotatorBFS::visit(const node::TermNodeIFace<node::NodeIdentIFace::IDENT>* _node)
{
    const_cast<node::TermNodeIFace<node::NodeIdentIFace::IDENT>*>(_node)->set_bfs_index(m_bfs_index++);
}

void TreeAnnotatorBFS::visit_null()
{
    m_bfs_index++;
}

void IndentedLispPrinter::visit(const node::SymbolNodeIFace* _node)
{
    m_output_ss << std::string(m_depth * 4, ' ') << '(' << _node->name() << std::endl;
    m_depth++;
    VisitorDFS::visit(_node);
    m_depth--;
    m_output_ss << std::string(m_depth * 4, ' ') << ')' << std::endl;
}

void IndentedLispPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::INT>* _node)
{
    m_output_ss << std::string(m_depth * 4, ' ');
    VisitorDFS::visit(_node);
    m_output_ss << std::endl;
}

void IndentedLispPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::FLOAT>* _node)
{
    m_output_ss << std::string(m_depth * 4, ' ');
    VisitorDFS::visit(_node);
    m_output_ss << std::endl;
}

void IndentedLispPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::STRING>* _node)
{
    m_output_ss << std::string(m_depth * 4, ' ');
    VisitorDFS::visit(_node);
    m_output_ss << std::endl;
}

void IndentedLispPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::CHAR>* _node)
{
    m_output_ss << std::string(m_depth * 4, ' ');
    VisitorDFS::visit(_node);
    m_output_ss << std::endl;
}

void IndentedLispPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::IDENT>* _node)
{
    m_output_ss << std::string(m_depth * 4, ' ');
    VisitorDFS::visit(_node);
    m_output_ss << std::endl;
}

void IndentedLispPrinter::visit_null()
{
    m_output_ss << std::string(m_depth * 4, ' ') << "(NULL)" << std::endl;
}

void LispPrinter::visit(const node::SymbolNodeIFace* _node)
{
    m_output_ss << '(' << _node->name();
    m_depth++;
    VisitorDFS::visit(_node);
    m_depth--;
    m_output_ss << ')';
    if(m_depth <= 1) {
        m_output_ss << std::endl;
    }
}

void LispPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::INT>* _node)
{
    m_output_ss << " ";
    VisitorDFS::visit(_node);
}

void LispPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::FLOAT>* _node)
{
    m_output_ss << " ";
    VisitorDFS::visit(_node);
}

void LispPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::STRING>* _node)
{
    m_output_ss << " ";
    VisitorDFS::visit(_node);
}

void LispPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::CHAR>* _node)
{
    m_output_ss << " ";
    VisitorDFS::visit(_node);
}

void LispPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::IDENT>* _node)
{
    m_output_ss << " ";
    VisitorDFS::visit(_node);
}

void LispPrinter::visit_null()
{
    m_output_ss << std::string(m_depth * 4, ' ') << "(NULL)" << std::endl;
}

void XMLPrinter::visit(const node::SymbolNodeIFace* _node)
{
    m_output_ss << std::string(m_depth * 4, ' ') << "<symbol ";
#ifdef INCLUDE_NODE_UID
    m_output_ss << "id=" << _node->uid() << " ";
#endif
    m_output_ss << "type=\"" << _node->name() << "\">" << std::endl;
    m_depth++;
    VisitorDFS::visit(_node);
    m_depth--;
    m_output_ss << std::string(m_depth * 4, ' ') << "</symbol>" << std::endl;
}

void XMLPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::INT>* _node)
{
    m_output_ss << std::string(m_depth * 4, ' ') << "<term ";
#ifdef INCLUDE_NODE_UID
    m_output_ss << "id=" << _node->uid() << " ";
#endif
    m_output_ss << "type=\"" << _node->name() << "\" value=";
    VisitorDFS::visit(_node);
    m_output_ss << "/>" << std::endl;
}

void XMLPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::FLOAT>* _node)
{
    m_output_ss << std::string(m_depth * 4, ' ') << "<term ";
#ifdef INCLUDE_NODE_UID
    m_output_ss << "id=" << _node->uid() << " ";
#endif
    m_output_ss << "type=\"" << _node->name() << "\" value=";
    VisitorDFS::visit(_node);
    m_output_ss << "/>" << std::endl;
}

void XMLPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::STRING>* _node)
{
    m_output_ss << std::string(m_depth * 4, ' ') << "<term ";
#ifdef INCLUDE_NODE_UID
    m_output_ss << "id=" << _node->uid() << " ";
#endif
    m_output_ss << "type=\"" << _node->name() << "\" value=";
    m_output_ss << '\"' << xl::escape_xml(*_node->value()) << '\"';
    m_output_ss << "/>" << std::endl;
}

void XMLPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::CHAR>* _node)
{
    m_output_ss << std::string(m_depth * 4, ' ') << "<term ";
#ifdef INCLUDE_NODE_UID
    m_output_ss << "id=" << _node->uid() << " ";
#endif
    m_output_ss << "type=\"" << _node->name() << "\" value=";
    VisitorDFS::visit(_node);
    m_output_ss << "/>" << std::endl;
}

void XMLPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::IDENT>* _node)
{
    m_output_ss << std::string(m_depth * 4, ' ') << "<term ";
#ifdef INCLUDE_NODE_UID
    m_output_ss << "id=" << _node->uid() << " ";
#endif
    m_output_ss << "type=\"" << _node->name() << "\" value=";
    VisitorDFS::visit(_node);
    m_output_ss << "/>" << std::endl;
}

void XMLPrinter::visit_null()
{
    m_output_ss << std::string(m_depth * 4, ' ') << "<NULL/>" << std::endl;
}

void DotPrinter::visit(const node::SymbolNodeIFace* _node)
{
    if(m_print_digraph_block && _node->is_root()) {
        m_output_ss << print_header(m_horizontal);
    }
    m_output_ss << "\t" << _node->uid() << " [" << std::endl
                << "\t\tlabel=\"" << _node->name() << "\"," << std::endl
                << "\t\tshape=\"ellipse\"" << std::endl
                << "\t];" << std::endl;
    VisitorDFS::visit(_node);
    if(!_node->is_root()) {
        m_output_ss << '\t' << _node->parent()->uid() << "->" << _node->uid() << ";" << std::endl;
    }
    if(m_print_digraph_block && _node->is_root()) {
        m_output_ss << print_footer();
    }
}

void DotPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::INT>* _node)
{
    m_output_ss << "\t" << _node->uid() << " [" << std::endl
                << "\t\tlabel=\"" << _node->value() << "\"," << std::endl
                << "\t\tshape=\"box\"" << std::endl
                << "\t];" << std::endl
                << '\t' << _node->parent()->uid() << "->" << _node->uid() << ";" << std::endl;
}

void DotPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::FLOAT>* _node)
{
    m_output_ss << "\t" << _node->uid() << " [" << std::endl
                 << "\t\tlabel=\"" << _node->value() << "\"," << std::endl
                 << "\t\tshape=\"box\"" << std::endl
                 << "\t];" << std::endl
                 << '\t' << _node->parent()->uid() << "->" << _node->uid() << ";" << std::endl;
}

void DotPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::STRING>* _node)
{
    m_output_ss << "\t" << _node->uid() << " [" << std::endl
                << "\t\tlabel=\"" << xl::escape(*_node->value()) << "\"," << std::endl
                << "\t\tshape=\"box\"" << std::endl
                << "\t];" << std::endl
                << '\t' << _node->parent()->uid() << "->" << _node->uid() << ";" << std::endl;
}

void DotPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::CHAR>* _node)
{
    m_output_ss << "\t" << _node->uid() << " [" << std::endl
                << "\t\tlabel=\"" << xl::escape(_node->value()) << "\"," << std::endl
                << "\t\tshape=\"box\"" << std::endl
                << "\t];" << std::endl
                << '\t' << _node->parent()->uid() << "->" << _node->uid() << ";" << std::endl;
}

void DotPrinter::visit(const node::TermNodeIFace<node::NodeIdentIFace::IDENT>* _node)
{
    m_output_ss << "\t" << _node->uid() << " [" << std::endl
                << "\t\tlabel=\"" << *_node->value() << "\"," << std::endl
                << "\t\tshape=\"box\"" << std::endl
                << "\t];" << std::endl
                << '\t' << _node->parent()->uid() << "->" << _node->uid() << ";" << std::endl;
}

void DotPrinter::visit_null()
{
    m_output_ss << "/* NULL */";
}

std::string DotPrinter::print_header(bool horizontal)
{
    std::stringstream ss;
    ss << "digraph g {" << std::endl;
    if(horizontal) {
        ss << "\tgraph [rankdir = \"LR\"];" << std::endl;
    }
    return ss.str();
}

std::string DotPrinter::print_footer()
{
    std::stringstream ss;
    ss << "}" << std::endl;
    return ss.str();
}

} }
