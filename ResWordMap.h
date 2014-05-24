
#ifndef __RESWORDMAP_H__
#define __RESWORDMAP_H__
#include "DebugUtilities.h"
#include <map>
#include <string>

class ReservedWordMap: public map<string, int>, public DebugUtilities
{
		typedef pair<string, int> ReservedWordMapPair;
	public:
		inline ReservedWordMap()
		{
			this->insert(ReservedWordMapPair("input",RES_INPUT));
			this->insert(ReservedWordMapPair("output",RES_OUTPUT));
			this->insert(ReservedWordMapPair("inout",RES_INOUT));
			this->insert(ReservedWordMapPair("always",RES_ALWAYS));
			this->insert(ReservedWordMapPair("or",RES_OR));
			this->insert(ReservedWordMapPair("initial",RES_INITIAL));
			this->insert(ReservedWordMapPair("if",RES_IF));
			this->insert(ReservedWordMapPair("else",RES_ELSE));
			this->insert(ReservedWordMapPair("case",RES_CASE));
			this->insert(ReservedWordMapPair("casex",RES_CASEX));
			this->insert(ReservedWordMapPair("casez",RES_CASEZ));
			this->insert(ReservedWordMapPair("for",RES_FOR));
			this->insert(ReservedWordMapPair("begin",RES_BEGIN));
			this->insert(ReservedWordMapPair("end",RES_END));
			this->insert(ReservedWordMapPair("fork",RES_FORK));
			this->insert(ReservedWordMapPair("join",RES_JOIN));
			this->insert(ReservedWordMapPair("wire",RES_WIRE));
			this->insert(ReservedWordMapPair("assign",RES_ASSIGN));
			this->insert(ReservedWordMapPair("reg",RES_REG));
			this->insert(ReservedWordMapPair("integer",RES_INTEGER));
			this->insert(ReservedWordMapPair("module",RES_MODULE));
			this->insert(ReservedWordMapPair("function",RES_FUNCTION));
			this->insert(ReservedWordMapPair("task",RES_TASK));
			this->insert(ReservedWordMapPair("parameter",RES_PARAMETER));
			this->insert(ReservedWordMapPair("default",RES_DEFAULT));
			this->insert(ReservedWordMapPair("endcase",RES_ENDCASE));
			this->insert(ReservedWordMapPair("endmodule",RES_ENDMODULE));
			this->insert(ReservedWordMapPair("endfunction",RES_ENDFUNCTION));
			this->insert(ReservedWordMapPair("endtask",RES_ENDTASK));
			this->insert(ReservedWordMapPair("negedge",RES_NEGEDGE));
			this->insert(ReservedWordMapPair("posedge",RES_POSEDGE));
			this->insert(ReservedWordMapPair("`include",RES_INCLUDE_));
			this->insert(ReservedWordMapPair("`define",RES_DEFINE_));

			this-> inform((typeName(*this) + string(" inited")).c_str());
		}
		virtual ~ReservedWordMap() {};

		friend ostream& operator << (ostream& os, const ReservedWordMap& o)
		{
			os << typeName(o) << ":: \n";
			return os;
		}

		//-------------------------

		inline int lookUpReservedWord(const char* text)
		{
			int result;
			return (find(text) == end()) ? inform((string(text) + string("不是保留字")).c_str(), -1) : inform((string(text) + string("是保留字")).c_str(), find(text)->second);
		}
};
#endif // !__RESWORDMAP_H__
