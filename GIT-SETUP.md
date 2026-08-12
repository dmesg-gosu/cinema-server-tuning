# Инструкция по инициализации Git репозитория

## Шаг 1: Настройка Git (если первый раз)

```powershell
git config --global user.name "Evgeny Samsonov"
git config --global user.email "zhecao98@gmail.com"
```

## Шаг 2: Инициализация локального репозитория

```powershell
cd C:\Temp\opencode
git init
```

## Шаг 3: Добавь все файлы в staging area

```powershell
git add .
```

## Шаг 4: Создай первый commit

```powershell
git commit -m "Initial commit: cinema server tuning kit

- Add baseline diagnostics script
- Add cinema-test-suite for basic performance testing
- Add cinema-test-suite-advanced for comprehensive tests (RAID, large blocks, concurrent I/O)
- Add diagnose-server utility for full system diagnostics
- Add network and RAID tuning scripts
- Add sysctl performance configuration
- Add comprehensive README with project structure and usage guide
- Add .gitignore for test files and temporary data"
```

## Шаг 5: Переименуй main ветку (GitHub стандарт)

```powershell
git branch -M main
```

## Шаг 6: Проверь статус

```powershell
git status
git log --oneline
```

---

## Теперь создаём репозиторий на GitHub

1. Открой https://github.com/new
2. Назови репозиторий: `cinema-server-tuning`
3. Выбери:
   - ☐ Public (или Private если нужно)
   - ☐ Initialize with README (НЕ выбирай, у нас уже есть)
4. Нажми "Create repository"

## Шаг 7: Добавь remote и загрузи код

```powershell
# Замени USERNAME на свой GitHub username
git remote add origin https://github.com/USERNAME/cinema-server-tuning.git
git branch -M main
git push -u origin main
```

---

## Если что-то пошло не так

### Проверить текущий remote:
```powershell
git remote -v
```

### Удалить неправильный remote:
```powershell
git remote remove origin
```

### Затем добавить правильный:
```powershell
git remote add origin https://github.com/USERNAME/cinema-server-tuning.git
```

---

## Готово! Теперь проверь на GitHub:
https://github.com/USERNAME/cinema-server-tuning
