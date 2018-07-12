#!/bin/bash

PLIK_1=""
PLIK_2=""
start ()
{
    OPCJE=$1
    ZNAK=0;
    while [ $ZNAK != 9 ]
    do
        OPCJA=$(zenity --list --title "Analiza historii i zaladek  przegladarki" --text "Wybierz opcje" --column=Opcje: "${OPCJE[@]}" --height 370 --width 350)
        ZNAK=${OPCJA:0:1}
        case $ZNAK in
           1) wykresy;;
           2) kalendarz;;
           3) wyszukaj;;
           4) zakladki;;
        esac
    done
}
rysujJedenSlupek ()
{
    NAM=$(awk "NR==$(($1+1)){print;exit}" "nazwy.txt")
echo "Liczba sluplow: "$LICZBA_SLUPKOW
    echo $T'<text x="'$[ 200+500*$2/$MAX_WARTOSC+1 ]'" y="'$[ 20*$1+$1+13 ]'" fill="red"  text-anchor="start" font-size="10">'$2'</text>' >>wykres.html
    echo $T'<rect x="200" y="'$[ 20*$1+$1 ]'" width="'$[ 500*$2/$MAX_WARTOSC ]'" height="20" style="fill:blue"/>' >>wykres.html
    echo $T'<text x="195" y="'$[ 20*$1+$1+14 ]'" fill="black"  text-anchor="end" font-size="10">'$NAM'</text>' >>wykres.html
}

rysujWykres ()
{
    LICZBA_SLUPKOW=`wc -w < nazwy.txt`
    if [[ $LICZBA_SLUPKOW -gt $2 ]] ; then
        LICZBA_SLUPKOW=$2
    fi
    MAX_WARTOSC=`sort -nr liczby.txt | head -1`
    
    echo '<div style="margin:20px">'$1'<div><svg width="740"height='$[ $LICZBA_SLUPKOW*21+20 ]'>' >>wykres.html
    NUM=0;
    for LICZBA in `cat liczby.txt`
    do
        if [[ $NUM -gt $2 ]] ; then     #większe lub róœne
            break
        fi   
        rysujJedenSlupek "$NUM" "$LICZBA"
        NUM=$(($NUM+1))
        
    done
    echo "</svg>" >>wykres.html
    echo $T > aa.html
    
    rm liczby.txt
    rm nazwy.txt
    #echo $T
}

znajdzCalaHistorie ()
{
    sqlite3 "$PLIK_1" "SELECT url FROM moz_places, moz_historyvisits WHERE moz_places.id = moz_historyvisits.place_id;" |  grep "http" | cut -d'/' -f3  | sort | uniq -c | sort -nr > cale.txt
    awk '{ print $1 }' "cale.txt" >liczby.txt
    awk '{ print $2 }' "cale.txt"  > nazwy.txt
}


znajdzGodzinyWHistorii ()
{
    sqlite3 $PLIK_1 "SELECT datetime(visit_date/1000000,'unixepoch') FROM moz_places, moz_historyvisits WHERE moz_places.id = moz_historyvisits.place_id;"> godzina.txt
    cat godzina.txt | cut -d' ' -f2 | cut -d':' -f1 | sort | uniq -c > godzina.txt
     awk '{ print $1 }' godzina.txt >liczby.txt
    awk '{ print $2 }' godzina.txt  >nazwy.txt

}

znajdzDniTygodniaWHistorii ()
{
    sqlite3 $PLIK_1 "SELECT datetime(visit_date/1000000,'unixepoch') FROM moz_places, moz_historyvisits WHERE moz_places.id = moz_historyvisits.place_id;" | cut -d' ' -f1 > dni_tyg2.txt

    for DATA in `cat dni_tyg2.txt` ;
    do
        date -u -d "$DATA" +%u >>dni_tyg1.txt
    done
    cat dni_tyg1.txt | sort | uniq -c > dni_tyg.txt
    awk '{ print $1 }' dni_tyg.txt >liczby.txt
    for DZIEN_TYG in `cat dni_tyg1.txt | sort -u` ;
    do
        case $DZIEN_TYG in
           1) echo "PN" >>nazwy.txt;;
           2) echo "WT" >>nazwy.txt;;
           3) echo "SR" >>nazwy.txt;;
           4) echo "CZW" >>nazwy.txt;;
           5) echo "PT" >>nazwy.txt;;
           6) echo "SO" >>nazwy.txt;;
           7) echo "ND" >>nazwy.txt;;
        esac
    done

    rm dni_tyg1.txt
}

znajdzOstatniMiesiac ()
{
    sqlite3 $PLIK_1 "SELECT datetime(visit_date/1000000,'unixepoch') FROM moz_places, moz_historyvisits WHERE moz_places.id = moz_historyvisits.place_id;" | cut -d' ' -f1 > miesiac2.txt
    TERAZ=$(date -u +%s)
    for DATA in `cat miesiac2.txt` :
    do
        if [[ $DATA != ":" ]] ; then
        HISTORIA=$(date -u -d "$DATA 30 days" +%s)
 
        if [[ $TERAZ -gt $HISTORIA ]] ; then
            break
        fi
        echo $DATA
        echo $DATA >> miesiac1.txt
fi
    done
    cat miesiac1.txt | sort | uniq -c >miesiac.txt
    awk '{ print $1 }' miesiac.txt >liczby.txt
    awk '{ print $2 }' miesiac.txt  >nazwy.txt

    rm miesiac1.txt

}

wykresy ()
{
    echo '<!DOCTYPE html><html><head><meta charset="UTF-8"></head><body>' >wykres.html
    znajdzCalaHistorie 
    rysujWykres "Najczęściej odwiedzane strony" 10
    znajdzGodzinyWHistorii
    rysujWykres "Godzinowy rozkład odwiedzanych stron" 24
    znajdzDniTygodniaWHistorii
    rysujWykres "Tygodniowy rozkład odwiedzanych stron" 7
    znajdzOstatniMiesiac
    rysujWykres "Aktywność w ciągu ostatnich 30 dni" 30

    echo "</body></html>" >>wykres.html
    echo "wykresy"
}
kalendarz ()
{
    WYBRANE=$(zenity --calendar)
    DATA=$(echo $WYBRANE | sed -E "s/([0-9]{2}).([0-9]{2}).([0-9]{4})/\3-\2-\1/")
    DATA_PLUS_JEDEN=$(date -u -d "$DATA 1 day" +%Y-%m-%d)
    
    TERAZ=$(date -u +%s)
    HISTORIA=$(date -u -d "$DATA" +%s)
 
    if [[ $TERAZ -gt $HISTORIA ]] ; then
        sqlite3 $PLIK_1 "SELECT datetime(visit_date/1000000,'unixepoch'), url FROM moz_places, moz_historyvisits WHERE moz_places.id = moz_historyvisits.place_id and visit_date >= strftime('%s', '$DATA 00:00:00')*1000000 and visit_date < strftime('%s', '$DATA_PLUS_JEDEN')*1000000;" | cut -d' ' -f2 | tr "|" " " >kalendarz.txt

for LINE in `cat kalendarz.txt` :
        do
            #echo $LINE
            TITLE=$(echo $LINE | cut -d'|' -f1)
            
            if [[ $TITLE == "" ]] ; then
                TITLE=$(echo $LINE | cut -d'\' -f2 | cut -d'/' -f3)
                echo $TITLE
            fi
            #echo $TITLE
            echo $TITLE >>tytul.txt
        done

 zenity --list --height 370 --width 350 --column="godzina"  --column="adres strony"  $(cat kalendarz.txt)
    fi
    #elif komunikat - zła date
}
wyszukaj ()
{
    ZAPYTANIE=$(zenity --entry --title="wyszukaj" --text="Wpisz fragment strony")
    sqlite3 $PLIK_1 "SELECT datetime(visit_date/1000000,'unixepoch'), url FROM moz_places, moz_historyvisits WHERE moz_places.id = moz_historyvisits.place_id;"| grep  "$ZAPYTANIE" | tr "|" " " | sort -nr >wyszukaj.txt
    zenity --list --height 370 --width 450 --column="data" --column="godzina" --column="adres strony"  $(cat wyszukaj.txt)
    echo "wyszukaj"
}
zakladki ()
{
    echo "zakladki"
}
PLIK_1=`find "/home" -name "places.sqlite" | grep "mozilla"` 
if [[ $PLIK_1 != "" ]] ; then                 #pozmieniać przy drugim pliku
    OPCJE[0]="1 wygeneruj wykresy i zapisz w formacie html"
    OPCJE[1]="2 wyszukaj historie z kalendarza"
    OPCJE[2]="3 wyszukaj strony w historii"
    if [[ $PLIK_1 != "" ]] ; then
        OPCJE[2]+=" i/lub zakladkach"
        OPCJE[3]="4 wygeneruj drzewo zakladek do html"
    fi
echo "to: "$OPCJE
    start "$OPCJE"
elif [[ $PLIK_1 = "" ]] ; then
    zenity --title "Nie znaleziono plikOw"  --error --text="Program nie będzie działał, ponieważ nie znaleziono żadnych plików zawierających historię lub zakładki przeglądarek."
fi

