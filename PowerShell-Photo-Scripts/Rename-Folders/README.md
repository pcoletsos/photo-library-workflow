# Photo Folder Renaming Scripts

This repository contains a set of PowerShell scripts designed to organize photo and video folders in a two-step process.

---

## The Workflow

The organization process is designed to be run in two distinct steps. You should always run Step 1 before running Step 2.

### Step 1: Add Date Prefixes

**Purpose:** To add a consistent `YYYY-MM - ` prefix to all your event folders. This makes them sort chronologically by default.

**Scripts to use:**
1.  `Add-Prefix-Date-01-Safe-Mode.ps1`
2.  `Add-Prefix-Date-02-Live-Mode.ps1`

**How it works:**
This script looks inside each folder, finds the oldest file (based on its "Date Taken" or creation date), and uses that date to generate the prefix. For example, a folder named `My Vacation` will be renamed to `2011-07 - My Vacation`.

---

### Step 2: Add Keyword Descriptions

**Purpose:** After prefixing, this step adds a more descriptive, human-readable tag to each folder name, such as `(Christmas 2011)` or `(BIRTHDAY 2017)`.

**Scripts to use:**
1.  `Rename-By-Keyword-01-Safe-Mode.ps1`
2.  `Rename-By-Keyword-02-Live-Mode.ps1`

**How it works:**
This script looks for keywords like "Christmas" or "Pasxa" in the folder name. If it finds one, it creates a descriptive tag. If no keyword is found, it defaults to a `(BIRTHDAY YYYY)` tag. The final result will look something like this: `2011-07 - (BIRTHDAY 2011) - My Vacation`.

---

## How to Use the Scripts

For both steps, the process is the same:

1.  **Place the Scripts:** Copy the script you want to use into the main parent folder that contains all the event folders you want to rename (e.g., into `BIRTHDAYS_FESTIVITIES`).

2.  **Run the Safe Mode Script First:** Always start with the "Safe" version (e.g., `Add-Prefix-Date-01-Safe-Mode.ps1`). Open a PowerShell terminal in your parent folder and run it by typing its name:
    ```powershell
    .\Add-Prefix-Date-01-Safe-Mode.ps1
    ```
    This will show you a preview of all the changes it *would* make without actually changing anything.

3.  **Review the Output:** Check the messages in the terminal to make sure the proposed changes look correct.

4.  **Run the Live Mode Script:** If you are happy with the preview, run the "Live" version of the script (e.g., `Add-Prefix-Date-02-Live-Mode.ps1`) to make the changes permanent:
    ```powershell
    .\Add-Prefix-Date-02-Live-Mode.ps1
    ```

Remember to follow the sequence: complete all of **Step 1** on your folders before moving on to **Step 2**.