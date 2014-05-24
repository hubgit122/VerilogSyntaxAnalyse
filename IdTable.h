#ifndef __IDTABLE_H__
#define __IDTABLE_H__
#include "DebugUtilities.h"
#include "IdTableIntry.h"

class IdTable: public DebugUtilities
{
		typedef pair<string, int> Pair;
	public:
		map<string, int> map_string_int;
		IdTableIntry IdTableEntry;
		typedef map<string, int>::iterator It;

		inline IdTable(): id(0)
		{
			inform((typeName(*this) + string(" inited")).c_str());
		}
		virtual ~IdTable() {};

		friend ostream& operator << (ostream& os, const IdTable& o)
		{
			os << typeName(o) << ":: \n";
			return os;
		}

		//-------------------------
		inline virtual int symLookup(const char* text)
		{
			It p = map_string_int.find(text);
			int result;
			ostringstream oss;
			oss << text;

			if (p == map_string_int.end())
			{
				map_string_int.insert(Pair(text, id));
				result = id++ ;
				oss << "被识别为";
			}
			else
			{
				result = p->second;
				oss << "是从前识别过的";
			}

			oss << "标识符, 分配的ID号为" << result;
			inform(oss.str().c_str());
			return result;
		}
	private:
		int id;
};
#endif // !__IDTABLE_H__