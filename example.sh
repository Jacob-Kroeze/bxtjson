# # thanks http://adpgtech.blogspot.com/2014/09/importing-json-data.html
# cat /tmp/aisc-17306-33197722.txt \
#     | bin/bxtjson -s ../baxtore2/docs/schema/api.json -cc --entity=contract \
#     | psql2 -d bxt_development \
#     -c "copy contracts (document) \
#         from STDIN csv quote e'\x01' delimiter e'\x02'" \
#     2>&1 >/dev/null | grep -B 3 -A 3 syntax

#cat  /tmp/aisc-17306-33197722.txt | bin/bxtjson -s
#../baxtore2/docs/schema/api.json -e contract -cc  | psql2 -d
#bxt_development -c  "copy contracts (document) from STDIN csv escape
#e'\x01' quote e'\x01' delimiter e'\x02'";

# time = 0m20.330s
# with parallel = 30 sec ! so this is not useful write now.
# time = 

# psql2 -d bxt_development -c  "delete from contracts" \
#     && time cat /tmp/aisc-17306* | bin/bxtjson -s ../baxtore2/docs/schema/api.json -e contract -cc  | psql2 -d bxt_development -c "copy contracts (document) from STDIN csv quote e'\x01' delimiter e'\x02'"
# psql2 -d bxt_development -c "delete from contracts" && \
# time \
#  pgloader --type csv \
#      --field document \
#  --with "fields terminated by '0x02'" \
#  -- with "fields escaped by '0x02'"   \
#  -- with "fields optionally enclosed by '0x01'" \
#      - \
#      postgresql://bxt_development?tablename=contracts \
# 
#      < cat /tmp/aisc-17306* | bin/bxtjson -s ../baxtore2/docs/schema/api.json -e contract -cc \


#psql2 -d bxt_development -c "delete from contracts"    \
#    &&  \
cat /tmp/aisc-17306*   \
    | ../bxtjson/bin/bxtjson -s ../baxtore2/docs/schema/api.json -e contract -cc   \
    | pgloader --client-min-messages critical --log-min-messages critical \
    --summary summary.json ../bxt-migrations/loaders/contracts.load 
