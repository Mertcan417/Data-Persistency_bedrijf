-- ------------------------------------------------------------------------
-- Data & Persistency
-- Opdracht S7: Indexen
--
-- (c) 2020 Hogeschool Utrecht
-- Tijmen Muller (tijmen.muller@hu.nl)
-- André Donk (andre.donk@hu.nl)
-- ------------------------------------------------------------------------
-- LET OP, zoals in de opdracht op Canvas ook gezegd kun je informatie over
-- het query plan vinden op: https://www.postgresql.org/docs/current/using-explain.html


-- S7.1.
--
-- Je maakt alle opdrachten in de 'sales' database die je hebt aangemaakt en gevuld met
-- de aangeleverde data (zie de opdracht op Canvas).
--
-- Voer het voorbeeld uit wat in de les behandeld is:
-- 1. Voer het volgende EXPLAIN statement uit:

   EXPLAIN SELECT * FROM order_lines WHERE stock_item_id = 9;
--    Bekijk of je het resultaat begrijpt. Kopieer het explain plan onderaan de opdracht

-- "Gather  (cost=1000.00..6150.27 rows=990 width=96)"
-- "  Workers Planned: 2"
-- "  ->  Parallel Seq Scan on order_lines  (cost=0.00..5051.27 rows=412 width=96)"
-- "        Filter: (stock_item_id = 9)"


-- 2. Voeg een index op stock_item_id toe:
   CREATE INDEX ord_lines_id ON order_lines (stock_item_id);

-- 3. Analyseer opnieuw met EXPLAIN hoe de query nu uitgevoerd wordt
EXPLAIN SELECT * FROM order_lines WHERE stock_item_id = 9;
--    Kopieer het explain plan onderaan de opdracht

-- "Bitmap Heap Scan on order_lines  (cost=11.97..2277.83 rows=990 width=96)"
-- "  Recheck Cond: (stock_item_id = 9)"
-- "  ->  Bitmap Index Scan on ord_lines_si_id_idx  (cost=0.00..11.72 rows=990 width=0)"
-- "        Index Cond: (stock_item_id = 9)"

-- 4. Verklaar de verschillen. Schrijf deze hieronder op.
--het verschil in tijd zit er vooral in, omdat de SELECT query zonder de aangemaakte index sequentioneel wordt nagelopen
--dat verklaart de lange tijdsduur. Bij de SELECT query met de aangemaakte index wordt alles in een andere vorm nagelopen
--namelijk in de vorm van een soort mapje, hetgeen wat we wilden vinden gaat hierdoor sneller door de meegegeven index, wat gekoppeld
--is aan het stock_item_id;

-- S7.2.
--
-- 1. Maak de volgende twee query’s:
-- 	  A. Toon uit de order tabel de order met order_id = 73590

SELECT * FROM orders
WHERE order_id = 73590;

-- 	  B. Toon uit de order tabel de order met customer_id = 1028

SELECT * FROM orders
WHERE customer_id = 1028;

-- 2. Analyseer met EXPLAIN hoe de query’s uitgevoerd worden en kopieer het explain plan onderaan de opdracht
EXPLAIN SELECT * FROM orders
WHERE order_id = 73590;
-- "Index Scan using pk_sales_orders on orders  (cost=0.29..8.31 rows=1 width=155)"
-- "  Index Cond: (order_id = 73590)"

EXPLAIN SELECT * FROM orders
WHERE customer_id = 1028;
-- "Seq Scan on orders  (cost=0.00..1819.94 rows=107 width=155)"
-- "  Filter: (customer_id = 1028)"

-- 3. Verklaar de verschillen en schrijf deze op
--De query met de order_id maakt gebruik van een index en duur korter, de query met de customer_id doorloopt het sequentioneel, heeft geen id en duurt langer.

-- 4. Voeg een index toe, waarmee query B versneld kan worden
CREATE INDEX index_customer_id ON orders(customer_id);

-- 5. Analyseer met EXPLAIN en kopieer het explain plan onder de opdracht
EXPLAIN SELECT * FROM orders
        WHERE customer_id = 1028;

-- "Bitmap Heap Scan on orders  (cost=5.12..308.96 rows=107 width=155)"
-- "  Recheck Cond: (customer_id = 1028)"
-- "  ->  Bitmap Index Scan on index_customer_id  (cost=0.00..5.10 rows=107 width=0)"
-- "        Index Cond: (customer_id = 1028)"

-- 6. Verklaar de verschillen en schrijf hieronder op
--De eerste is zonder index en duurt langer en doorloopt het sequentioneel, de tweede niet. deze heeft een index, en gebruikt een bitmap index scan methode wat veel korter duurt.

-- S7.3.A
--
-- Het blijkt dat customers regelmatig klagen over trage bezorging van hun bestelling.
-- Het idee is dat verkopers misschien te lang wachten met het invoeren van de bestelling in het systeem.
-- Daar willen we meer inzicht in krijgen.
-- We willen alle orders (order_id, order_date, salesperson_person_id (als verkoper),
--    het verschil tussen expected_delivery_date en order_date (als levertijd),
--    en de bestelde hoeveelheid van een product zien (quantity uit order_lines).
-- Dit willen we alleen zien voor een bestelde hoeveelheid van een product > 250
--   (we zijn nl. als eerste geïnteresseerd in grote aantallen want daar lijkt het vaker mis te gaan)
-- En verder willen we ons focussen op verkopers wiens bestellingen er gemiddeld langer over doen.
-- De meeste bestellingen kunnen binnen een dag bezorgd worden, sommige binnen 2-3 dagen.
-- Het hele bestelproces is er op gericht dat de gemiddelde bestelling binnen 1.45 dagen kan worden bezorgd.
-- We willen in onze query dan ook alleen de verkopers zien wiens gemiddelde levertijd
--  (expected_delivery_date - order_date) over al zijn/haar bestellingen groter is dan 1.45 dagen.
-- Maak om dit te bereiken een subquery in je WHERE clause.
-- Sorteer het resultaat van de hele geheel op levertijd (desc) en verkoper.
-- 1. Maak hieronder deze query (als je het goed doet zouden er 377 rijen uit moeten komen, en het kan best even duren...)

CREATE OR REPLACE VIEW VERKOOP AS

SELECT o.order_id,
       o.order_date,
       o.salesperson_person_id AS verkoper,
       ABS(DATE_PART('day',o.expected_delivery_date) - DATE_PART('day',o.order_date)) AS levertijd,
       ol.quantity
FROM orders o
         JOIN order_lines ol ON
        ol.order_id = o.order_id
WHERE ol.quantity > 250
  AND o.salesperson_person_id IN (SELECT o.salesperson_person_id
                                  FROM orders o
                                  GROUP BY o.salesperson_person_id
                                  HAVING AVG(o.expected_delivery_date - o.order_date) > 1.45)
ORDER BY levertijd DESC, verkoper DESC;


-- S7.3.B
--
-- 1. Vraag het EXPLAIN plan op van je query (kopieer hier, onder de opdracht)

EXPLAIN SELECT * FROM VERKOOP;
-- "Gather Merge  (cost=9708.87..9735.47 rows=228 width=20)"
-- "  Workers Planned: 2"
-- "  ->  Sort  (cost=8708.85..8709.13 rows=114 width=20)"
-- "        Sort Key: (abs((o.expected_delivery_date - o.order_date))) DESC, o.salesperson_person_id DESC"
-- "        ->  Hash Join  (cost=2188.42..8704.95 rows=114 width=20)"
-- "              Hash Cond: (o.salesperson_person_id = o_1.salesperson_person_id)"
-- "              ->  Nested Loop  (cost=0.29..6514.84 rows=379 width=20)"
-- "                    ->  Parallel Seq Scan on order_lines ol  (cost=0.00..5051.27 rows=379 width=8)"
-- "                          Filter: (quantity > 250)"
-- "                    ->  Index Scan using pk_sales_orders on orders o  (cost=0.29..3.86 rows=1 width=16)"
-- "                          Index Cond: (order_id = ol.order_id)"
-- "              ->  Hash  (cost=2188.09..2188.09 rows=3 width=4)"
-- "                    ->  HashAggregate  (cost=2187.91..2188.06 rows=3 width=4)"
-- "                          Group Key: o_1.salesperson_person_id"
-- "                          Filter: (avg((o_1.expected_delivery_date - o_1.order_date)) > 1.45)"
-- "                          ->  Seq Scan on orders o_1  (cost=0.00..1635.95 rows=73595 width=12)"

-- 2. Kijk of je met 1 of meer indexen de query zou kunnen versnellen

CREATE INDEX index_salesperson_person_id ON orders (salesperson_person_id);

--de query runt al snel, maar dit kan een mogelijkheid bieden (deze zit namelijk in de subquery, wat vertragingstijd kan opleveren)

-- 3. Maak de index(en) aan en run nogmaals het EXPLAIN plan (kopieer weer onder de opdracht)

EXPLAIN SELECT * FROM VERKOOP;
-- "Gather Merge  (cost=9708.87..9735.47 rows=228 width=20)"
-- "  Workers Planned: 2"
-- "  ->  Sort  (cost=8708.85..8709.13 rows=114 width=20)"
-- "        Sort Key: (abs((o.expected_delivery_date - o.order_date))) DESC, o.salesperson_person_id DESC"
-- "        ->  Hash Join  (cost=2188.42..8704.95 rows=114 width=20)"
-- "              Hash Cond: (o.salesperson_person_id = o_1.salesperson_person_id)"
-- "              ->  Nested Loop  (cost=0.29..6514.84 rows=379 width=20)"
-- "                    ->  Parallel Seq Scan on order_lines ol  (cost=0.00..5051.27 rows=379 width=8)"
-- "                          Filter: (quantity > 250)"
-- "                    ->  Index Scan using pk_sales_orders on orders o  (cost=0.29..3.86 rows=1 width=16)"
-- "                          Index Cond: (order_id = ol.order_id)"
-- "              ->  Hash  (cost=2188.09..2188.09 rows=3 width=4)"
-- "                    ->  HashAggregate  (cost=2187.91..2188.06 rows=3 width=4)"
-- "                          Group Key: o_1.salesperson_person_id"
-- "                          Filter: (avg((o_1.expected_delivery_date - o_1.order_date)) > 1.45)"
-- "                          ->  Seq Scan on orders o_1  (cost=0.00..1635.95 rows=73595 width=12)"

-- 4. Wat voor verschillen zie je? Verklaar hieronder.

--Er zit geen verschil in opvraagtijd,zie niet echt een verschil.


-- S7.3.C
--
-- Zou je de query ook heel anders kunnen schrijven om hem te versnellen?

--ik zie zelf geen andere mogelijkheid,
-- de subquery zelf zorgt ook wel voor de vertraging van opvraagtijd,
-- maar ik weet niet hoe je dit kan omzetten naar een join.
